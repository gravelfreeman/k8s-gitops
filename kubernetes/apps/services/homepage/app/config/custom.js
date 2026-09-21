/*
 * Catppuccin theme for Homepage by Gravel Freeman
 */

(() => {
  // Set the dark flavor and accent to any official Catppuccin color here.
  const config = { darkFlavor: "frappe", accent: "mauve" };
  const accentColors = new Set(["rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach", "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender"]);
  const root = document.documentElement;
  const lightScale = {
    50: "mantle", // main background
    100: "surface1", // services level 0+bookmarks background
    200: "surface0", // services level 1 background
    300: "overlay0", // selected tab
    400: "accent", // loading spinner
    500: "accent", // charts and primary accent
    600: "accent", // secondary accent
    700: "text", // main text, header progress bars
    800: "text", // category+header text, icons
    900: "text", // category icons
  };
  const darkScale = {
    50: "base", // defaults to other vars
    100: "base", // defaults to other vars
    200: "text", // main text
    300: "subtext0", // category text, bookmarks link text
    400: "accent", // loading spinner
    500: "accent", // charts and primary accent
    600: "accent", // secondary accent
    700: "overlay0", // search results overlay
    800: "base", // main background
    900: "surface2", // services level 1 background
  };

  const themeRoles = {
    light: {
      label: "subtext0",
      shadow: "text",
      "card-bg": "base",
      "card-hover": "surface0",
      "block-bg": "mantle",
      "progress-track": "mantle",
      "progress-fill": "crust",
      "status-hover": "overlay0",
      "tabs-bg": "crust",
      "tab-active": "surface0",
      "tab-hover": "mantle",
      "bookmark-bg": "base",
      "bookmark-hover": "surface0",
      "bookmark-icon": "mantle",
    },
    dark: {
      label: "subtext0",
      shadow: "crust",
      "card-bg": "surface0",
      "card-hover": "overlay0",
      "block-bg": "surface1",
      "progress-track": "surface1",
      "progress-fill": "surface2",
      "status-hover": "overlay2",
      "tabs-bg": "mantle",
      "tab-active": "surface0",
      "tab-hover": "overlay0",
      "bookmark-bg": "surface0",
      "bookmark-hover": "overlay0",
      "bookmark-icon": "surface1",
    },
  };

  const applyTheme = () => {
    const isDark = root.classList.contains("dark") || root.classList.contains("scheme-dark");
    const flavor = isDark ? config.darkFlavor : "latte";
    const scale = isDark ? darkScale : lightScale;
    const roles = themeRoles[isDark ? "dark" : "light"];
    const accent = accentColors.has(config.accent) ? config.accent : "blue";
    const accentValue = "var(--catppuccin-" + flavor + "-" + accent + ")";

    Object.entries(roles).forEach(([role, token]) => {
      root.style.setProperty(
        "--theme-" + role,
        "var(--catppuccin-" + flavor + "-" + token + ")",
      );
    });
    Object.entries(scale).forEach(([step, token]) => {
      const color = token === "accent" ? accent : token;
      root.style.setProperty("--color-" + step, "var(--catppuccin-" + flavor + "-" + color + ")");
    });
    root.style.setProperty("--theme-accent", accentValue);
    ["blue", "green", "red", "yellow", "overlay2", "rosewater", "text"].forEach((color) => {
      root.style.setProperty("--catppuccin-" + color, "var(--catppuccin-" + flavor + "-" + color + ")");
    });
  };

  new MutationObserver(applyTheme).observe(root, { attributeFilter: ["class"] });
  applyTheme();

  // Status dots for Prometheus and other dynamic status lists
  const applyStatusDots = () => {
    document.querySelectorAll(".service-card .service-container").forEach((container) => {
      const firstItem = container.firstElementChild?.firstElementChild;
      container.classList.toggle("homepage-dynamic-list", firstItem?.tagName === "A");
    });

    document
      .querySelectorAll(".service-card .service-container > div > a")
      .forEach((row) => {
        const status = row.lastElementChild?.textContent?.trim().toLowerCase() ?? "";
        const color = /failed|failing|critical/.test(status)
          ? "red"
          : /suspended|warning/.test(status)
            ? "yellow"
            : /\bnone\b/.test(status)
              ? "green"
              : null;
        const name = row.firstElementChild;
        const dot = name?.querySelector(".homepage-status-dot");

        if (!name) return;
        if (!color) {
          dot?.remove();
          return;
        }
        if (!dot) {
          const newDot = document.createElement("span");
          newDot.className = "homepage-status-dot homepage-status-dot-" + color;
          newDot.setAttribute("aria-hidden", "true");
          name.prepend(newDot);
          return;
        }
        dot.className = "homepage-status-dot homepage-status-dot-" + color;
        dot.setAttribute("aria-hidden", "true");
      });
  };

  new MutationObserver(applyStatusDots).observe(document.body, { childList: true, subtree: true });
  applyStatusDots();

  // Show Alertmanager descriptions in the native tooltip
  const applyAlertDescriptions = () => {
    const marker = "#homepage-alert-description=";

    document.querySelectorAll(".service-card .service-container > div > a").forEach((row) => {
      const markerIndex = row.href.indexOf(marker);
      if (markerIndex === -1) return;

      const encodedDescription = row.href.slice(markerIndex + marker.length);
      let description = encodedDescription;
      try {
        description = decodeURIComponent(encodedDescription);
      } catch {
        // Keep the raw fragment if an alert contains an invalid percent sequence.
      }
      if (description) row.title = description;
    });
  };

  new MutationObserver(applyAlertDescriptions).observe(document.body, { childList: true, subtree: true });
  applyAlertDescriptions();

})();
