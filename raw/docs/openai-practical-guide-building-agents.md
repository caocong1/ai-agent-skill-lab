# OpenAI, A Practical Guide to Building Agents - structured digest

- Source URL: https://openai.com/business/guides-and-resources/a-practical-guide-to-building-ai-agents/
- PDF URL: https://cdn.openai.com/business-guides-and-resources/a-practical-guide-to-building-agents.pdf
- Publish date: not explicitly stated on the fetched HTML or PDF
- Fetch date: 2026-05-20
- Fetch method: Cursor `WebFetch` for both HTML and PDF
- Copyright note: This file is a paraphrased factual digest for analysis, not a verbatim copy of the original guide.

## Scope

OpenAI frames agents as systems that independently complete workflows on a user's behalf. The guide targets product and engineering teams building first production agents, with emphasis on use-case selection, core design components, orchestration, guardrails, and human fallback.

## Agent definition

The guide distinguishes agents from ordinary LLM features. A simple chatbot, classifier, or single-turn generation flow is not an agent unless the model manages workflow execution, decides when work is complete, can recover or stop on failure, and uses tools within explicit guardrails.

The basic components are:

- model: the reasoning and decision component;
- tools: external capabilities for context gathering or side effects;
- instructions: behavior rules, task routines, and guardrails.

## When to build one

OpenAI recommends agents for workflows where deterministic automation struggles:

- nuanced decisions with exceptions or context-sensitive judgment;
- brittle or expensive rule systems;
- heavy reliance on unstructured documents, language, or conversational input.

If those criteria are not clear, a deterministic system or simpler LLM workflow may be sufficient.

## Model, tools, and instructions

For model selection, the guide suggests starting with a capable model to establish a quality baseline, then replacing parts of the workflow with cheaper or faster models where evaluation shows quality remains acceptable.

For tools, it groups capabilities into:

- data tools that retrieve context;
- action tools that modify external systems or communicate;
- orchestration tools where one agent is exposed as a capability to another.

For instructions, it recommends converting existing operating procedures, support scripts, policy documents, and edge-case handling into clear model-facing routines with explicit actions and branches.

## Orchestration

OpenAI recommends incremental orchestration. A single agent with a well-defined tool set is often simpler to evaluate and maintain. Multiple agents become useful when instructions contain too many conditional branches, prompt templates no longer scale, or similar tools confuse the model despite improved naming and descriptions.

The guide distinguishes two multi-agent shapes:

- manager pattern: one central agent delegates specialized tasks through tool calls and remains responsible for synthesis and user continuity;
- handoff pattern: a peer agent transfers control to another specialist that continues the interaction.

It also contrasts code-first orchestration with declarative graph frameworks. The practical guidance is to choose the style that fits the workflow's predictability and maintenance needs rather than adopting a graph for its own sake.

## Guardrails and human intervention

The guide treats guardrails as layered controls, not a single filter. It lists relevance checks, safety checks, PII filters, moderation, tool safeguards, deterministic rules, and output validation. Tool safeguards should consider action risk, reversibility, required permissions, and financial or user impact.

Human intervention is recommended when failure thresholds are exceeded or when a requested action is high-risk, sensitive, irreversible, or not yet trusted enough for full automation.

## Relevance to this lab

This source complements Anthropic's workflow-vs-agent framing with product-facing selection criteria and production controls. It strengthens the lab's guidance on model baselines, single-agent-first orchestration, when to split agents, layered guardrails, tool risk ratings, and explicit handoff to humans.
