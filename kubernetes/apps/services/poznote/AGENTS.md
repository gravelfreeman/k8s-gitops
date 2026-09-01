# Poznote custom CSS

Instructions minimales pour maintenir `custom.css`.

## Périmètre

- Modifier uniquement `custom.css` pour le thème custom.
- `poznote/` est une référence en lecture seule : y rechercher les variables
  et le fonctionnement natif, sans y modifier de fichier.
- Ne pas ajouter de règles de composants, de mise en page, de comportement,
  de HTML ou de JavaScript.
- Ne pas maintenir de correctifs legacy, de sélecteurs spécifiques ou de
  doublons dans `custom.css`.

## Organisation obligatoire

Garder les sections dans cet ordre :

1. Les palettes complètes `--ctp-latte-*`, `--ctp-frappe-*` et
   `--ctp-mocha-*`.
2. Les tokens natifs `--pz-*` de Latte dans `:root`.
3. Les tokens natifs `--pz-*` et `--dm-*` de Frappé dans
   `html[data-theme='dark']` et son `body`.
4. Les tokens natifs `--pz-*` et `--dm-*` de Mocha dans
   `html.theme-black[data-theme='dark']` et son `body`.
5. Le fond racine partagé, uniquement si nécessaire pour neutraliser une
   couleur inline de Poznote.

Utiliser les variables natives `--pz-*` et `--dm-*` documentées dans
`poznote/src/css/dark-mode/variables.css` et `poznote/src/css/README.md`.
Les variables `--ctp-*` sont réservées aux palettes complètes du début de
fichier. Les blocs de thème mappent directement les variables natives vers ces
couleurs, sans alias intermédiaire.
Le fichier doit rester court, lisible et organisé par palette. Les commentaires
doivent expliquer l’intention du bloc, pas recopier le code source.

## Catppuccin

- Utiliser uniquement les couleurs de la
  [palette Catppuccin](https://catppuccin.com/palette/).
- Respecter le [style guide Catppuccin](https://github.com/catppuccin/catppuccin/blob/main/docs/style-guide.md#general-usage).
- L’accent de chaque flavor est `Blue`, avec sa valeur Catppuccin propre.
  `Hover` et `strong` sont des variantes assombries du même `Blue`, jamais une
  autre couleur d’accent. Pour changer de rôle, modifier les mappings natifs,
  pas les palettes.
- Utiliser une couleur Catppuccin cohérente comme variante d’interaction.
- Préserver les rôles Catppuccin : `Base`, `Mantle`, `Crust`, `Surface`,
  `Text`, `Subtext`, `Blue`, `Green`, `Yellow` et `Red`.

## Règles d’édition

- Privilégier un changement de token natif à toute règle CSS ciblée.
- Pour changer l’accent, modifier uniquement les références natives d’accent
  dans les trois blocs de thème, jamais les palettes.
- Ne pas utiliser `!important`, `*`, d’ID, `:has()` ou de sélecteurs de
  composant. L’unique exception autorisée est le fond racine documenté, qui
  doit neutraliser la couleur inline de Poznote sur `html`.
- Ne pas utiliser `body.dark-mode` / `body.black-mode` comme sélecteurs de
  composants. Le ciblage du `body` dans les blocs de tokens est requis car
  Poznote y redéfinit nativement les `--dm-*`.
- Ne pas recopier de CSS upstream. Une nouvelle règle hors des palettes, du
  mapping ou des blocs natifs est interdite sans justification explicite.
- Ne pas modifier `custom.bak`.

## Procédure

1. Lire la définition et l’usage du token dans le code de référence.
2. Mapper le besoin sur un rôle Catppuccin puis sur un token `--pz-*` ou
   `--dm-*` existant.
3. Modifier uniquement la section concernée.
4. Vérifier la syntaxe et l’absence de sélecteurs ou de couleurs superflus.
5. Tester les trois modes si un rôle ou un token partagé est modifié.
