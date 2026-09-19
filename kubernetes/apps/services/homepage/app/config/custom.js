(() => {
  // Change only these two values. darkFlavor: frappe | macchiato | mocha.
  const config = { darkFlavor: "frappe", accent: "mauve" };
  const root = document.documentElement;
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
    const flavor = root.classList.contains("dark") ? config.darkFlavor : "latte";
    const scale = root.classList.contains("dark") ? darkScale : lightScale;

    Object.entries(scale).forEach(([step, color]) => {
      const token = color === "accent" ? config.accent : color;
      root.style.setProperty("--color-" + step, "var(--catppuccin-" + flavor + "-" + token + ")");
    });

    ["blue", "overlay2", "rosewater", "text"].forEach((color) => {
      root.style.setProperty("--catppuccin-" + color, "var(--catppuccin-" + flavor + "-" + color + ")");
    });
    root.style.setProperty("--catppuccin-accent", "var(--catppuccin-" + flavor + "-" + config.accent + ")");
  };

  new MutationObserver(applyTheme).observe(root, { attributeFilter: ["class"] });
  applyTheme();
})();
