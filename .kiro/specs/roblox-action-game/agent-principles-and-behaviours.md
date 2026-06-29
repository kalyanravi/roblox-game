# Agent Principles & Behaviours: Roblox & Rojo/Kiro Edition

## Core Principles

- **Spec-Driven Architecture:** Do not jump straight to Luau code. Use Kiro's Spec mode to plan the architecture first. Explicitly define if the logic belongs on the Server (Script), Client (LocalScript), or Shared (ModuleScript). Map these clearly to your Rojo JSON configuration layout.

- **Roblox API & Luau Best Practices:** Always use `game:GetService()` to fetch services (e.g., `Players`, `ReplicatedStorage`, `TweenService`). Never index them directly. Use modern Luau features like type-checking (`--!strict`) where appropriate and use `task.wait()` instead of the deprecated `wait()`.

- **Networking & Security Focus:** Maintain a strict "Never Trust the Client" posture. Proactively secure `RemoteEvents` and `RemoteFunctions` on the server by validating all incoming player arguments. Prevent exploiters from abusing remote triggers.

- **Memory & Lifecycle Management:** Write clean, performant code optimized for cross-platform play (Mobile, Console, PC). Always disconnect event listeners (`:Disconnect()`) when objects or players leave to prevent catastrophic memory leaks.

- **Critical Reasoning and Honesty:** Identify and question false premises in user requests. If a requested feature causes server lag or breaks Roblox's network boundary, halt and suggest an optimal alternative (such as moving visual/tween calculations entirely to the client).

## Kiro Specification & Implementation Workflow

- **Rojo Compliance:** Every generated file must map cleanly to your Rojo file sync structure. Ensure file suffixes (`.server.luau`, `.client.luau`, `.luau`) align with your project's `default.project.json`.

- **Review the Task List:** Check off each subtask inside the Kiro implementation plan methodically as you write and test the code.

- **Verification:** Double-check edge cases before finishing a task, including how scripts handle a player disconnecting abruptly mid-execution.

- **Ask Before Documenting:** Explicitly ask the user if they require a breakdown of the Luau implementation. Do not automatically generate documentation unless the user confirms it.

- **Conclude Your Turn:** Await user response or next task assignment.
