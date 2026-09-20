(() => {
  const config = { darkFlavor: "frappe" };
  const root = document.documentElement;
  const lightScale = {
    50: "mantle", // main background
    100: "surface1", // services level 0+bookmarks background
    200: "surface0", // services level 1 background
    300: "overlay0", // selected tab
    400: "base", // loading border
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
    400: "subtext0", // version text, loading border
    500: "base", // defaults to other vars
    600: "subtext0", // secondary text
    700: "overlay0", // search results overlay
    800: "base", // main background
    900: "surface2", // services level 1 background
  };

  const themeRoles = {
    light: {
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

    Object.entries(roles).forEach(([role, token]) => {
      root.style.setProperty(
        "--theme-" + role,
        "var(--catppuccin-" + flavor + "-" + token + ")",
      );
    });
    root.style.setProperty(
      "--theme-label",
      "var(--catppuccin-" + (isDark ? "macchiato" : "latte") + "-subtext0)",
    );
    Object.entries(scale).forEach(([step, token]) => {
      root.style.setProperty("--color-" + step, "var(--catppuccin-" + flavor + "-" + token + ")");
    });
    ["blue", "green", "red", "peach", "yellow", "overlay0", "overlay2", "rosewater", "text"].forEach((color) => {
      root.style.setProperty("--catppuccin-" + color, "var(--catppuccin-" + flavor + "-" + color + ")");
    });
  };

  new MutationObserver(applyTheme).observe(root, { attributeFilter: ["class"] });
  applyTheme();
})();
