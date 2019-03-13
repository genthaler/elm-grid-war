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
    - maybe use service worker to do game logic for AI?
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

Probably the most fun for me is the game logic, and it's the most reusable, so start there.

- only 1 class, 2 teams, no terrain (so no need for complex path finding)
- so only need 3 colours (1 for each team + 1 for neither)
- AI consists of random movement
- start with turn-based gameplay
- start with robots only
- need a GO button & action
- want a stream of events, so need some sort of data structure for that
- do I want a state machine?
- we want the game to progress at an orderly pace.
    - so we'll subscribe to a timer event for ticks to start new events

So the states are:
- Init
  - random allocation of units
- Wait for 
- Attack team
  - Circular list of teams
- Win

