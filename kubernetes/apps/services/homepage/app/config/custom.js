(() => {
  // Change only this value. darkFlavor: frappe | macchiato | mocha.
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
    50: "base",
    100: "mantle",
    200: "surface0",
    300: "surface1",
    400: "surface2",
    500: "accent",
    600: "overlay0",
    700: "subtext0",
    800: "text",
    900: "crust",
  };
  const darkScale = {
    50: "surface0",
    100: "surface1",
    200: "text",
    300: "subtext0",
    400: "subtext1",
    500: "accent",
    600: "overlay0",
    700: "surface2",
    800: "base",
    900: "crust",
  };

  const applyTheme = () => {
    const isDark = root.classList.contains("dark") || root.classList.contains("scheme-dark");
    const flavor = isDark ? config.darkFlavor : "latte";
    const scale = isDark ? darkScale : lightScale;
    const homepageColor = Array.from(root.classList)
      .find((className) => className.startsWith("theme-"))
      ?.slice(6);
    const accent = colorMap[homepageColor] || colorMap.slate;

    Object.entries(scale).forEach(([step, color]) => {
      const token = color === "accent" ? accent : color;
      root.style.setProperty("--color-" + step, "var(--catppuccin-" + flavor + "-" + token + ")");
    });

    ["blue", "overlay2", "rosewater", "text"].forEach((color) => {
      root.style.setProperty("--catppuccin-" + color, "var(--catppuccin-" + flavor + "-" + color + ")");
    });
    root.style.setProperty("--catppuccin-accent", "var(--catppuccin-" + flavor + "-" + accent + ")");
  };

  new MutationObserver(applyTheme).observe(root, { attributeFilter: ["class"] });
  applyTheme();
})();
