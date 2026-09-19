(() => {
  const config = { darkFlavor: "frappe" };
  const root = document.documentElement;
  const colorMap = {
    slate: "overlay0",
    gray: "overlay1",
    zinc: "surface2",
    neutral: "surface1",
    stone: "surface0",
    white: "base",
    amber: "yellow",
    yellow: "peach",
    lime: "green",
    green: "green",
    emerald: "teal",
    teal: "teal",
    cyan: "sapphire",
    sky: "sky",
    blue: "blue",
    indigo: "lavender",
    violet: "mauve",
    purple: "mauve",
    fuchsia: "pink",
    pink: "pink",
    rose: "flamingo",
    red: "red",
  };
  const lightScale = {
    50: "base", // main background
    100: "surface1", // services level 0+bookmarks background
    200: "surface0", // services level 1 background
    300: "overlay0", // selected tab
    400: "base", // color picker bg, loading border
    500: "surface2", // bookmarks icon background
    600: "subtext1", // secondary text
    700: "text", // main text, header progress bars
    800: "text", // category+header text, icons
    900: "text", // category icons
  };
  const darkScale = {
    50: "base", // defaults to other vars
    100: "base", // defaults to other vars
    200: "text", // main text
    300: "subtext0", // category text, bookmarks link text
    400: "subtext0", // version text, color picker bg, loading border
    500: "base", // defaults to other vars
    600: "subtext0", // secondary text
    700: "overlay0", // search results overlay
    800: "base", // main background
    900: "surface2", // services level 1 background
  };

  const applyTheme = () => {
    const isDark = root.classList.contains("dark") || root.classList.contains("scheme-dark");
    const flavor = isDark ? config.darkFlavor : "latte";
    const homepageColor = Array.from(root.classList)
      .find((className) => className.startsWith("theme-"))
      ?.slice(6);
    const accent = colorMap[homepageColor] || colorMap.slate;
    const scale = isDark ? darkScale : lightScale;

    Object.entries(scale).forEach(([step, color]) => {
      const token = color === "accent" ? accent : color;
      root.style.setProperty("--color-" + step, "var(--catppuccin-" + flavor + "-" + token + ")");
    });
    root.style.setProperty("--color-slate-700", "rgb(var(--color-700))"); // search results border
    ["blue", "green", "red", "peach", "yellow", "overlay2", "rosewater"].forEach((color) => {
      root.style.setProperty("--catppuccin-" + color, "var(--catppuccin-" + flavor + "-" + color + ")");
    });
    const accentToken = "var(--catppuccin-" + flavor + "-" + accent + ")";
    root.style.setProperty("--color-logo-start", accentToken);
    root.style.setProperty("--color-logo-stop", accentToken);
  };

  new MutationObserver(applyTheme).observe(root, { attributeFilter: ["class"] });
  applyTheme();
})();
