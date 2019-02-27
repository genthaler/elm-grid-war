# elm-grid-war

My homage to the hex-based strategy games of yesteryear

UniWar would be the game closest to what I'm looking at. Other games might be Myth, Warcraft, Glest.

The Elm hexagon libraries deal mostly with measurement and mutation, nothing to do with display, so that's my lookout.

I'm looking for a vector image look rather than an 8-bit look, so I'll go with SVG for the time being at least.

Otherwise I might have to fall back to gifs.

Feature list in no particular order:
- update all elm stuff from npm, atom, vscode, sublime, lighttable
- look for a good game template/bootstrap
- look for a simple SVG example
- serverless
- Look for a platform for free games for gamestate, player registration and lookup
- display a blank map
- display a map with some terrain
- display a map with some terrain and characters
- a character moving to a different location
- multiple characters moving
- two characters fighting
- make impossible states unrepresentable
- game play page
- give directions
- automatic actions
- text-based input of commands
- pause game?
- slow down game while typing?
- rotate map
- zoom into map
- progressive enhancement of SVG images
- move unit
- game selection page
- unit purchase/attribute page
- scalable graphics
- smooth animations
- smooth gameplay
- audio
- multi-player, networking
  - peer to peer play
    - probably still need a server for discovery
  - server based?
- native
  - Electron?
  - React Native?
  - Flux?
  - any new ones?
- keyboard controls
- show available moves
- show range of attack
- localstorage
- prove security properties
- schema versioning
- navigation/routing
- artificial intelligence
- strategies
- fog of war
- landing page

So I'll need a way to display

```
Feature display a map

Scenario display a map with one texture
```

Tasks
- Represent different maps for easy loading.
  - Probably easiest to use JSON & enoders & decoders. 
  - Also want to be able to compress and Base64 it for use as a url param/anchor
- Display basic hex grid
- Display different perspective
- Change perspective with keys
- Random allocation of basic soldiers
- Implement battle in text, use basic colours to show statuses
- Fight over time
- right-click for dialog to change orders
  - UI definition
