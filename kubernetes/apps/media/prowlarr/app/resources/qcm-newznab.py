#!/usr/bin/env python3
import sys

sys.dont_write_bytecode = True
for stream in (sys.stdout, sys.stderr):
    try:
        stream.reconfigure(line_buffering=True, write_through=True)
    except AttributeError:
        pass

import base64
import email.utils
import html
import http.cookiejar
import json
import os
import re
import threading
import traceback
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from xml.sax.saxutils import escape, quoteattr

BASE_URL = os.environ.get("QCM_BASE_URL", "").rstrip("/") + "/"
GATE_SECRET = os.environ.get("QCM_GATE_SECRET", "")
USERNAME = os.environ.get("QCM_USERNAME", "")
PASSWORD = os.environ.get("QCM_PASSWORD", "")
PROXY_URL = "http://gluetun-alfa-proxies.gluetun.svc.cluster.local:8888"
PORT = 9697
RESULT_LIMIT = 100
TIMEOUT = 20

NEWZNAB_CATEGORIES = {
    "2000": "Movies",
    "5000": "TV",
    "8000": "Other",
}

CATEGORY_PATHS = {
    "2000": ["genre/film/"],
    "5000": ["genre/series/", "genre/emissions/", "genre/documentaire/", "genre/humour/", "genre/spectacle/"],
}


def clean_text(value):
    value = re.sub(r"<script\b.*?</script>", " ", value or "", flags=re.I | re.S)
    value = re.sub(r"<style\b.*?</style>", " ", value, flags=re.I | re.S)
    value = re.sub(r"<br\s*/?>", " ", value, flags=re.I)
    value = re.sub(r"<[^>]+>", " ", value)
    value = html.unescape(value)
    return re.sub(r"\s+", " ", value).strip()


def absolutize(url):
    return urllib.parse.urljoin(BASE_URL, html.unescape(url or ""))


def encode_id(url):
    encoded = base64.urlsafe_b64encode(url.encode("utf-8")).decode("ascii")
    return encoded.rstrip("=")


def decode_id(value):
    padding = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode((value + padding).encode("ascii")).decode("utf-8")


def safe_download_url(url):
    parsed_base = urllib.parse.urlparse(BASE_URL)
    parsed = urllib.parse.urlparse(url)
    return parsed.scheme in {"http", "https"} and parsed.netloc == parsed_base.netloc and parsed.path.startswith("/psistips/") and parsed.path.lower().endswith(".nzb")


def extract_inputs(markup):
    data = {}
    for match in re.finditer(r"<input\b([^>]*)>", markup, flags=re.I | re.S):
        attrs = match.group(1)
        name_match = re.search(r"\bname\s*=\s*(['\"])(.*?)\1", attrs, flags=re.I | re.S)
        if not name_match:
            continue
        value_match = re.search(r"\bvalue\s*=\s*(['\"])(.*?)\1", attrs, flags=re.I | re.S)
        data[html.unescape(name_match.group(2))] = html.unescape(value_match.group(2)) if value_match else ""
    return data


def extract_form_action(markup, current_url):
    match = re.search(r"<form\b([^>]*)>", markup, flags=re.I | re.S)
    if not match:
        return current_url
    action = re.search(r"\baction\s*=\s*(['\"])(.*?)\1", match.group(1), flags=re.I | re.S)
    return urllib.parse.urljoin(current_url, html.unescape(action.group(2))) if action else current_url


def infer_category(post_url, page_path, title):
    source = f"{post_url} {page_path} {title}".lower()
    if "/genre/film" in source or re.search(r"/films?/", source):
        return "2000"
    if any(token in source for token in ["/series/", "/genre/series", "/genre/emissions", "/genre/documentaire", "/genre/humour", "/genre/spectacle"]):
        return "5000"
    if re.search(r"s\d{1,2}e\d{1,3}", title, flags=re.I):
        return "5000"
    return "8000"


def extract_nearby_post_url(markup, position):
    context = markup[max(0, position - 5000):position]
    urls = []
    for match in re.finditer(r"href\s*=\s*(['\"])(.*?)\1", context, flags=re.I | re.S):
        url = absolutize(match.group(2))
        parsed = urllib.parse.urlparse(url)
        if parsed.netloc != urllib.parse.urlparse(BASE_URL).netloc:
            continue
        if re.search(r"/(wp-admin|wp-content|gudreekr|choopsaz|genre|tag|page/\d+|feed|xmlrpc)", parsed.path):
            continue
        if parsed.path == "/":
            continue
        urls.append(url)
    return urls[-1] if urls else BASE_URL


def parse_releases(markup, page_path):
    releases = []
    seen = set()
    for match in re.finditer(r"data-links\s*=\s*(['\"])(.*?)\1", markup, flags=re.I | re.S):
        raw = html.unescape(match.group(2))
        try:
            links = json.loads(raw)
        except json.JSONDecodeError:
            continue
        post_url = extract_nearby_post_url(markup, match.start())
        for item in links:
            url = absolutize(item.get("url", ""))
            title = clean_text(item.get("name", ""))
            if item.get("type") != "n" or not title or not safe_download_url(url):
                continue
            release_id = encode_id(url)
            if release_id in seen:
                continue
            seen.add(release_id)
            category = infer_category(post_url, page_path, title)
            releases.append({
                "id": release_id,
                "guid": release_id,
                "title": title,
                "details": post_url,
                "download": url,
                "category": category,
                "size": 0,
                "pub_date": datetime.now(timezone.utc),
            })
            if len(releases) >= RESULT_LIMIT:
                return releases
    return releases


class QcmClient:
    def __init__(self):
        self.cookiejar = http.cookiejar.CookieJar()
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({"http": PROXY_URL, "https": PROXY_URL}), urllib.request.HTTPCookieProcessor(self.cookiejar))
        self.lock = threading.Lock()
        self.last_login = 0.0

    def request(self, path_or_url="", data=None):
        url = absolutize(path_or_url)
        body = None
        headers = {"User-Agent": "qcm-newznab/1.0"}
        if data is not None:
            body = urllib.parse.urlencode(data).encode("utf-8")
            headers["Content-Type"] = "application/x-www-form-urlencoded"
        req = urllib.request.Request(url, data=body, headers=headers)
        with self.opener.open(req, timeout=TIMEOUT) as response:
            payload = response.read()
            charset = response.headers.get_content_charset() or "utf-8"
            return payload.decode(charset, errors="replace"), response.headers, response.url

    def ensure_login(self):
        if not BASE_URL.strip("/") or not GATE_SECRET or not USERNAME or not PASSWORD:
            raise RuntimeError("Missing QCM_BASE_URL, QCM_GATE_SECRET, QCM_USERNAME, or QCM_PASSWORD")
        with self.lock:
            if time.time() - self.last_login < 900:
                return
            self.request("")
            login_page, _, login_url = self.request("", {"secret": GATE_SECRET})
            fields = extract_inputs(login_page)
            fields["user_login"] = USERNAME
            fields["user_pass"] = PASSWORD
            fields["remember_me"] = "on"
            action = extract_form_action(login_page, login_url)
            body, _, _ = self.request(action, fields)
            if "action=logout" not in body and "Logout" not in body:
                raise RuntimeError("QCM login failed")
            self.last_login = time.time()

    def search(self, query, categories):
        self.ensure_login()
        releases = []
        seen = set()
        for path in build_paths(query, categories):
            body, _, _ = self.request(path)
            for release in parse_releases(body, path):
                if categories and release["category"] not in categories:
                    continue
                if release["id"] in seen:
                    continue
                seen.add(release["id"])
                releases.append(release)
                if len(releases) >= RESULT_LIMIT:
                    return releases
        return releases

    def get_nzb(self, release_id):
        self.ensure_login()
        url = decode_id(release_id)
        if not safe_download_url(url):
            raise RuntimeError("Refusing non-QCM NZB URL")
        req = urllib.request.Request(url, headers={"User-Agent": "qcm-newznab/1.0"})
        with self.opener.open(req, timeout=TIMEOUT) as response:
            return response.read(), response.headers.get("Content-Type") or "application/x-nzb"


def build_paths(query, categories):
    query = (query or "").strip()
    if query:
        return ["?" + urllib.parse.urlencode({"s": query})]

    paths = []
    for category in sorted(categories):
        paths.extend(CATEGORY_PATHS.get(category, []))
    return paths or ["recherche/"]


def requested_categories(params):
    raw = params.get("cat", [""])[0]
    return {cat.strip() for cat in raw.split(",") if cat.strip() in NEWZNAB_CATEGORIES}


def effective_query(params):
    query = params.get("q", [""])[0].strip()
    season = params.get("season", [""])[0].strip()
    episode = params.get("ep", [""])[0].strip()
    if query and season and episode:
        return f"{query} S{int(season):02d}E{int(episode):02d}" if season.isdigit() and episode.isdigit() else query
    return query


def caps_xml():
    categories = "\n".join(f"      <category id={quoteattr(cat_id)} name={quoteattr(name)} />" for cat_id, name in NEWZNAB_CATEGORIES.items())
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<caps>
  <server title="QCM Newznab" email="" />
  <limits max="100" default="100" />
  <searching>
    <search available="yes" supportedParams="q" />
    <tv-search available="yes" supportedParams="q,season,ep,cat" />
    <movie-search available="yes" supportedParams="q,cat" />
  </searching>
  <categories>
{categories}
  </categories>
</caps>
"""


def error_xml(code, description):
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<error code={quoteattr(str(code))} description={quoteattr(description)} />
"""


def releases_xml(releases, self_base):
    now = email.utils.format_datetime(datetime.now(timezone.utc), usegmt=True)
    items = []
    for release in releases:
        query = urllib.parse.urlencode({"t": "get", "id": release["id"]})
        get_url = f"{self_base}/api?{query}"
        pub_date = email.utils.format_datetime(release["pub_date"], usegmt=True)
        items.append(f"""    <item>
      <title>{escape(release["title"])}</title>
      <guid isPermaLink="false">{escape(release["guid"])}</guid>
      <link>{escape(get_url)}</link>
      <comments>{escape(release["details"])}</comments>
      <pubDate>{pub_date}</pubDate>
      <category>{escape(NEWZNAB_CATEGORIES.get(release["category"], "Other"))}</category>
      <enclosure url={quoteattr(get_url)} length={quoteattr(str(release["size"]))} type="application/x-nzb" />
      <newznab:attr name="category" value={quoteattr(release["category"])} />
      <newznab:attr name="size" value={quoteattr(str(release["size"]))} />
      <newznab:attr name="guid" value={quoteattr(release["guid"])} />
      <newznab:attr name="details" value={quoteattr(release["details"])} />
    </item>""")
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:newznab="http://www.newznab.com/DTD/2010/feeds/attributes/">
  <channel>
    <title>QCM Newznab</title>
    <description>QCM scraper proxy</description>
    <link>{escape(BASE_URL)}</link>
    <language>fr-fr</language>
    <newznab:response offset="0" total={quoteattr(str(len(releases)))} />
    <pubDate>{now}</pubDate>
{chr(10).join(items)}
  </channel>
</rss>
"""


def xml_response(body):
    return body.encode("utf-8"), "application/xml; charset=utf-8", HTTPStatus.OK


class Handler(BaseHTTPRequestHandler):
    server_version = "qcm-newznab/1.0"

    def log_message(self, fmt, *args):
        message = fmt % args
        message = re.sub(r"apikey=[^&\s]+", "apikey=<redacted>", message, flags=re.I)
        sys.stderr.write("%s - - [%s] %s\n" % (self.client_address[0], self.log_date_time_string(), message))

    def send_body(self, data, content_type="text/plain; charset=utf-8", status=HTTPStatus.OK):
        if isinstance(data, str):
            data = data.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query, keep_blank_values=True)
        if parsed.path in {"/healthz", "/ping"}:
            self.send_body("ok\n")
            return
        if parsed.path == "/debug":
            self.send_body(json.dumps({
                "base_url_configured": bool(BASE_URL.strip("/")),
                "gate_secret_configured": bool(GATE_SECRET),
                "username_configured": bool(USERNAME),
                "password_configured": bool(PASSWORD),
                "proxy_configured": bool(PROXY_URL),
                "port": PORT,
                "result_limit": RESULT_LIMIT,
                "timeout": TIMEOUT,
            }) + "\n", "application/json; charset=utf-8")
            return
        if parsed.path != "/api":
            self.send_body("not found\n", status=HTTPStatus.NOT_FOUND)
            return

        action = params.get("t", ["caps"])[0].lower()
        try:
            if action == "caps":
                body, content_type, status = xml_response(caps_xml())
                self.send_body(body, content_type, status)
                return
            if action in {"search", "tvsearch", "movie", "movie-search"}:
                releases = self.server.client.search(effective_query(params), requested_categories(params))
                scheme = self.headers.get("X-Forwarded-Proto", "http")
                host = self.headers.get("Host", f"localhost:{PORT}")
                body, content_type, status = xml_response(releases_xml(releases, f"{scheme}://{host}"))
                self.send_body(body, content_type, status)
                return
            if action == "get":
                release_id = params.get("id", [""])[0]
                nzb, content_type = self.server.client.get_nzb(release_id)
                self.send_body(nzb, content_type or "application/x-nzb")
                return
            body, content_type, status = xml_response(error_xml(203, "Function not available"))
            self.send_body(body, content_type, status)
        except urllib.error.HTTPError as exc:
            self.send_body(f"upstream http error: {exc.code}\n", status=HTTPStatus.BAD_GATEWAY)
        except Exception as exc:
            traceback.print_exc(file=sys.stderr)
            self.send_body(f"error: {exc}\n", status=HTTPStatus.INTERNAL_SERVER_ERROR)


def main():
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    server.client = QcmClient()
    print(f"qcm-newznab listening on :{PORT}", file=sys.stderr)
    server.serve_forever()


if __name__ == "__main__":
    main()
