# ADR 0016: Issue Comments in Agent Context

Agents need the full GitHub issue discussion, not only the issue body. Important acceptance details,
operator corrections, and review direction often live in comments after the original description.

Symphony fetches issue comments with candidate issues and ordered queue issue lookups. Rendered Agent
Prompts include those comments when present, and Stage Goal Context carries the same comment data
when Stage Goal Handoff is enabled.

Issue comments supplement the Agent Prompt and Stage Goal Context. They do not replace the issue
description, Stage Agent instructions, Stage Skill Load, or Runtime Contract prompt template.
