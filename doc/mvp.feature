Feature: MVP
As a player of hex based games
In order to enjoy myself
I want to play a game

Scenario: Gamer visits the website for the first time
Given Gamer opens website
When the page loads
Then Gamer can see the landing page

Scenario: Tutorial
Scenario: New Game
Scenario: Restore Game
Scenario: Save Game

Scenario: Start Campaign
Scenario: Win Campaign
Scenario: Lose Campaign
Scenario: Start War
Scenario: Win War
Scenario: Lose War

Scenario: Start Turn
Given we are in a Campaign
Then we are in select mode

Scenario: Heal
Scenario: Move
Scenario: Attack
Given we are in a Campaign
When one piece attacks another
Then the attacker attacks using attack attributes
And the defender defends using defence attributes

Scenario: End Turn
Given we are in a Campaign
When we end the Turn
Then we determine the enemy actions
And we animate the enemy actions

Scenario: Defend
Given we are in a Campaign
And it is not our turn
When an enemy attacks our
Then we can select actions to perform on the ground

Scenario: Recruit
Scenario: Die
Scenario:

Scenario: Build
Given we are in a Campaign
And we are in select mode
When we click on the ground
Then we can select actions to perform on the ground


Scenario: Destroy

Scenario: Select type of new Recruit
Given are in a Campaign
When we are recruiting
Then we can choose the type of new Recruit

Scenario: Select type of new Building
Given are in a Campaign
When we are building
Then we can choose the type of new Building

Scenario: Draw map
Given we are in a Campaign
When the screen is drawn
Then we can see the part of the map that should be in focus

Scenario: Scroll map
Given we are in a Campaign
When we have moved the focus area
And the screen is drawn
Then we can see the part of the map that should be in focus

Scenario: Show statistics
Given we are in a Campaign
When the screen is drawn
Then we can see the latest statistics
