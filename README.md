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

- look up available free/pd/ccl graphics/sounds/models
- gif/svg/webgl/css
- Halt when there are no more members of a team
- Extract current AI as a module
- eExtract map generation as a module.
- Refine message passing? or use Debug.log? Currently using Result for message passing, not really working
- Start to refine the UI, use cell select to display statuses

## AI
### Types
- Completely random (current implementation)
- Drive in a (random) curvy line
- Drive in a straight line and bounce off the walls
- Neural Net
  - GAN
- Genetic Algorithms
- GA + NN
- Control Flow Theory / Feedback control
- swarming?
- Search (i.e. suck and see), prune, Minimax, AB-Pruning Minimax, and random agent
  - breadth-first
  - depth-first
  - would like to be able to keep relevant search results after a move

### Considerations
- GANs and Genetic Algorithms need time to learn, can't really do it in-game
- need to be able to interrupt the search in order to pick the best in the available time, and also to permit animations.
- how to allow genetically generated code to be interruptible?
- can have GA for longer lasting games, with waves or constantly spawning
- although we can have a variant where there is no central intelligence, rather NPCs just randomly spawn
