# Asset notes

Original art and music were supplied with the project. Original unused menu images remain as source assets but are not displayed by the new UI. No new licensing claim is made for the supplied assets.

Two replacements were made with the built-in image generation tool:

- `assets/passage_interior.png` — enclosed cave passage.
- `assets/title_cave.png` — clean title background for real animated nodes.

Final prompts:

**Passage:** Use case: precise-object-edit. Edit this 2D game cave corridor background. Preserve its purple/blue crystal cave illustration style, 16:9 composition, left interior tunnel, broad foreground walkable stone floor. Remove all bright exterior opening and daylight on the right, replacing it with a continuous enclosed cave corridor of dark rock and glowing crystals. No sky or sunlight or exterior exit. No characters, text, UI or border. Edge-to-edge interior cave art.

**Title:** Use case: precise-object-edit. Remove ALL overlays from this game title screen: lettering FINNY THE DRAGON, dragon, gold coin, chest, START button and cursor. Reconstruct the empty brown cartoon cave behind them. Preserve warm brown simple illustrated cave walls, dark central negative space, foreground ground, 16:9 composition. Only the clean empty cave background, no text, characters, coins, icons or UI. Real game nodes will supply animations and buttons.

`assets/menu_coin.svg` is an original code-drawn vector coin. `assets/background_music.ogg` is a Vorbis conversion of the supplied music so Godot can import and export it as a resource. The source MPEG is retained.

## Local co-op update

- The title uses the existing `passage_interior.png` crystal cave, live Finny sprite and live vector coin, with a layout inspired by the supplied screenshot. The screenshot's editor interface is not included in the game.
- `assets/fonts/PressStart2P-Regular.ttf`: Press Start 2P by CodeMan38, supplied by the Google Fonts repository. Source: https://github.com/google/fonts/tree/main/ofl/pressstart2p . The original SIL Open Font License is included as `assets/fonts/OFL.txt`.
- `assets/blue_finny.gdshader` changes Finny's green scales to blue at runtime. It reuses the original animations and leaves light belly, horns and eyes unchanged.
- Arena floor, player rings and attack warnings are drawn by Godot code. Goblins and ogres reuse the project's supplied sprites. The boss is the ogre at a larger scale with a warm tint.

## Story introduction and SFX update

- `assets/story/grandfather.jpg`, `empty_chest.jpg`, `king.jpg`: unchanged copies of the three user-supplied illustrations. Embedded English dialogue is preserved; the intro fits each whole square image without cropping.
- `assets/story/idea.png`: a new fourth panel generated with the built-in image tool, using the three supplied images as style and character references. The English dialogue is rendered live by Godot.
- All six WAV files in `assets/sfx/` are original procedural synthesis, with no external samples. Reproducible source: `tools/generate_sfx.py` (Python standard library, fixed random seed). PCM16 mono at 44,100 Hz, normalized below full scale and with faded edges. No separate audio download is needed.
- Intro script follows the supplied “Finny the Dragon: Boss Fight Inc.” document: million-coin promise, empty chest and 5,000 debt, seven-day ultimatum, paid boss-fight idea and the goblin asking for a job.

**Fourth-panel final prompt:** Use case: illustration-story. Create the FOURTH illustrated comic panel for the Godot game Finny the Dragon: Boss Fight Inc. The three input images are STYLE and CHARACTER references, not edit targets. Match their inked detailed storybook comic style, warm cave stone, adorable lime green baby dragon Finny with gold horns, large black eyes and pale belly. New square composition: Finny stands at his cave entrance and has a delighted clever idea while looking at two armored adventurer knights outside on the path, searching for a dragon to fight. One knight has a shield and sword sheathed; another gestures toward the cave. A small friendly goblin peeks from inside the cave wanting a job. Finny holds up a shiny gold coin and gestures welcomingly, realizing he can sell staged boss fights. Optimistic funny mood, afternoon light, matching illustrative detail and anatomy. No grandfather and no king. No text, no speech bubbles, no letters, no watermark, no UI: English dialogue will be live game text. Keep all characters inside the frame. This is a new story panel consistent with the three supplied illustrations.
