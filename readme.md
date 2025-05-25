# Cool Colin Crosses the Causeway - Proof of Concept (POC)

## About This POC

This repository contains the Proof of Concept (POC) for "Cool Colin Crosses the Causeway," a 3D exploration and discovery game starring Cool Colin, an inquisitive dog.

The primary goal of this POC was to:
1.  Establish core third-person character movement and basic action controls for Colin.
2.  Implement a system for discovering items within the game world.
3.  Demonstrate that these discoveries are not just collectibles, but **data points** that can be tracked and acted upon by a central game manager.
4.  Showcase a simple branching outcome based on the *types* of discoveries made, laying the groundwork for a more complex knowledge graph system.
5.  Test basic multi-zone transitions.

This POC successfully demonstrates these foundational elements.

## Key Features Demonstrated in the POC

*   **Character Control:**
    *   Third-person movement for Cool Colin (Walk, Sprint with a basic stamina system, Jump).
    *   Basic dog-like actions: Sit, Lie Down, Bark, Sniff, Dig, Give Paw (when sitting).
    *   Animation state management for these actions.
*   **Discovery System:**
    *   16 unique "Discoverable" items distributed across a few small test zones.
    *   Each discoverable has a defined `category` (e.g., Artifacts, Memory, Landscapes, Natural Phenomena) and a required `interaction_type` (Sniff, Dig, Bark) to uncover it.
*   **Game Management & Progression:**
    *   `GameManager` tracks all 16 discoveries made by the player.
    *   Progression is currently linear: finding all 16 discoveries triggers a final sequence.
    *   The system logs which categories of discoveries are completed.
*   **Dynamic Outcome (POC Level):**
    *   Upon finding all 16 discoveries, the player is transported to a "Final Zone."
    *   In the Final Zone, a final "dig" interaction reveals one of two items (a Tennis Ball or a Big Bone).
    *   The item revealed, and Colin's subsequent final animation (Sit & Think or Lie & Dream), is determined by the **category of the last set of four discoveries completed by the player**. This demonstrates a basic principle of how accumulated "knowledge" (in this case, category completion order) can influence game events and narrative.
*   **Zone Transitions:** Players can move between different simple zones via `ZoneExit` areas.
*   **Basic UI:**
    *   Displays the number of discoveries found / total.
    *   Shows a stamina bar for sprinting.
    *   A countdown timer and message for the transition to the Final Zone.
    *   A "POC COMPLETED!" screen summarizing the outcome.

## How to Experience the POC

1.  Ensure you have Godot Engine (version 4.3 or compatible) installed.
2.  Clone this repository.
3.  Open the project in Godot Engine.
4.  Run the `main.tscn` scene (or whichever is set as the main scene).
5.  **Controls:**
    *   **Movement:** WASD
    *   **Camera:** Mouse
    *   **Jump:** Spacebar
    *   **Sprint:** Hold Shift
    *   **Sit/Stand up from Sit:** Q
    *   **Lie Down/Stand up from Lie:** Z
    *   **Bark:** B
    *   **Sniff:** N
    *   **Dig:** M
    *   **Give Paw (when sitting):** E
    *   **Pause:** P (or Esc, depending on input map)
6.  **Objective:** Explore the connected zones and use Colin's abilities to find all 16 discoverable items. Once all are found, follow the prompts to the final zone for the conclusion.

## Technology

*   Developed using **Godot Engine 4.3**.

## Beyond the POC

This POC serves as a solid foundation. The next steps (MVP/Demo) will build upon this by:
*   Implementing a more detailed knowledge graph where individual discoveries have explicit relationships.
*   Introducing NPC characters (like Chromatic Carl) with reactive dialogue.
*   Developing environmental puzzles that require observation and deduction based on acquired knowledge.
*   Creating a player journal to visually represent and connect discoveries.
*   Expanding the narrative and world lore of The Island.

---

Thank you for checking out Cool Colin's POC!