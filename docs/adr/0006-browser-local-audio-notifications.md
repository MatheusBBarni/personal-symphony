# Browser-local Audio Notifications

## Status

Accepted

## Context

The Web Dashboard receives Runtime State snapshots through the Live Dashboard Connection. Operators need an opt-in browser sound when Symphony needs attention or active work finishes, but audio preferences are local browser behavior and should not change the Runtime Contract.

## Decision

The Web Dashboard owns Audio Notifications. It persists the enabled preference in browser local storage and compares consecutive Runtime State snapshots to decide whether to play a built-in browser-generated tone.

The initial Runtime State snapshot never emits an Audio Notification. A Work Became Idle transition emits the completion tone when running and retrying counts both reach zero after previously having running or retrying work. A Task Needs Attention transition emits the attention tone when a new Runtime State issue error appears.

Task Needs Attention has priority over Work Became Idle when both transitions appear in the same observed snapshot change. Retryable task errors and the Runtime State global last error do not emit Audio Notifications.

## Consequences

Audio Notifications remain browser-local and opt-in. Symphony does not add backend notification events, Runtime Settings, audio assets, or notification history for this behavior.

Because eligibility is derived from observed Runtime State snapshots, a reconnect that delivers a current snapshot is treated like any other next snapshot after the latest snapshot the browser has seen.
