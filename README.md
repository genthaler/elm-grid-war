# elm-grid-war

My homage to the hex-based strategy games of yesteryear

## Feature categories
### Game setup
  - display a map with some terrain and characters
  - map/game editor
  - save & load game
    - plain text (JSON/Base64/Some other encoding)
    - localstorage
    - schema versioning
    - history? CRDT?
### Game play
  - implement battle in text
    - use basic colours to show statuses
    - need a console?
  - move-based vs continuous play
  - slow down game while typing?
  - pause game?
  - a character moving to a different location
  - multiple characters moving
  - two characters fighting
  - keyboard controls
  - show available moves
  - show range of attack
  - text-based input of commands
  - move unit
  - game selection page
  - unit purchase/attribute page
  - fog of war
  - AI
    - strategies
    - automatic actions
    - map generation - terraform
    - path finding - A*
### Game experience
  - look for a simple SVG example
  - rotate map
  - zoom into map
  - progressive enhancement of SVG images
  - scalable graphics
  - smooth animations
  - smooth gameplay
  - audio
  - elm-geometry
  - elm-3d-camera  
### Help
  - game play page
  - give directions
### Multiplayer
  - Look for a platform for free games for gamestate, player registration and lookup
  - serverless
  - peer to peer play
    - probably still need a server for discovery
  - server based?
  - prove security properties
  - vote to change game speed
### Native
  - Electron?
  - React Native?
  - Flux?
  - Flutter?
  - any new ones?

## Tasks
- bigger cells
- write characters and teams
- maybe use service worker to do game logic for AI?
