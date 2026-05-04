type counts = {
  running: int,
  retrying: int,
}

type issueError = {
  issue_id: string,
  issue_identifier: string,
}

type runtimeState = {
  counts: counts,
  issue_errors: array<issueError>,
}

type audioContext
type oscillator
type gainNode
type audioParam
type destination
type localStorage

let preferenceKey = "personal-symphony.audioNotifications.enabled"
let audioContext = ref(None)

@val @scope("globalThis") external localStorage: localStorage = "localStorage"
@send external getItem: (localStorage, string) => string = "getItem"
@send external setItem: (localStorage, string, string) => unit = "setItem"
@val @scope("globalThis") external setTimeout: (unit => unit, int) => unit = "setTimeout"
@get external state: audioContext => string = "state"
@get external currentTime: audioContext => float = "currentTime"
@get external destination: audioContext => destination = "destination"
@send external resume: audioContext => unit = "resume"
@send external createOscillator: audioContext => oscillator = "createOscillator"
@send external createGain: audioContext => gainNode = "createGain"
@set external setOscillatorType: (oscillator, string) => unit = "type"
@get external frequency: oscillator => audioParam = "frequency"
@get external gain: gainNode => audioParam = "gain"
@send external setValueAtTime: (audioParam, float, float) => unit = "setValueAtTime"
@send external exponentialRampToValueAtTime: (audioParam, float, float) => unit = "exponentialRampToValueAtTime"
@send external connectToGain: (oscillator, gainNode) => unit = "connect"
@send external connectToDestination: (gainNode, destination) => unit = "connect"
@send external start: (oscillator, float) => unit = "start"
@send external stop: (oscillator, float) => unit = "stop"

%%raw(`
function createBrowserAudioContext() {
  const AudioContextCtor = globalThis.AudioContext || globalThis.webkitAudioContext;
  return AudioContextCtor ? new AudioContextCtor() : undefined;
}
`)

@val external createBrowserAudioContext: unit => option<audioContext> = "createBrowserAudioContext"

let getAudioContext = () => {
  switch audioContext.contents {
  | Some(context) => Some(context)
  | None =>
    switch createBrowserAudioContext() {
    | Some(context) =>
      audioContext := Some(context)
      Some(context)
    | None => None
    }
  }
}

let unlockAudioContext = () => {
  switch getAudioContext() {
  | Some(context) if context->state == "suspended" => context->resume
  | _ => ()
  }
}

let playTone = (~frequencyValue, ~durationMs, ~oscillatorType, ~gainValue) => {
  switch getAudioContext() {
  | None => ()
  | Some(context) =>
    if context->state == "suspended" {
      context->resume
    }

    let oscillator = context->createOscillator
    let gainNode = context->createGain
    let startTime = context->currentTime
    let endTime = startTime +. (durationMs->Float.fromInt /. 1000.0)

    oscillator->setOscillatorType(oscillatorType)
    oscillator->frequency->setValueAtTime(frequencyValue, startTime)
    gainNode->gain->setValueAtTime(0.0001, startTime)
    gainNode->gain->exponentialRampToValueAtTime(gainValue, startTime +. 0.015)
    gainNode->gain->exponentialRampToValueAtTime(0.0001, endTime)

    oscillator->connectToGain(gainNode)
    gainNode->connectToDestination(context->destination)
    oscillator->start(startTime)
    oscillator->stop(endTime)
  }
}

let readAudioNotificationsEnabled = () => {
  try {
    localStorage->getItem(preferenceKey) == "true"
  } catch {
  | _ => false
  }
}

let setAudioNotificationsEnabled = enabled => {
  try {
    localStorage->setItem(preferenceKey, if enabled {
      "true"
    } else {
      "false"
    })
  } catch {
  | _ => ()
  }

  if enabled {
    unlockAudioContext()
  }
}

let issueErrorKey = error =>
  if error.issue_id != "" {
    error.issue_id
  } else {
    error.issue_identifier
  }

let hasIssueError = (issueErrors, targetKey) => {
  let found = ref(false)
  for index in 0 to Array.length(issueErrors) - 1 {
    switch issueErrors[index] {
    | Some(error) =>
      if issueErrorKey(error) == targetKey {
        found := true
      }
    | None => ()
    }
  }
  found.contents
}

let hasNewIssueError = (previous, next) => {
  let found = ref(false)
  for index in 0 to Array.length(next.issue_errors) - 1 {
    switch next.issue_errors[index] {
    | Some(error) =>
      if !hasIssueError(previous.issue_errors, issueErrorKey(error)) {
        found := true
      }
    | None => ()
    }
  }
  found.contents
}

let audioNotificationForTransition = (previous: option<runtimeState>, next: runtimeState): option<string> => {
  switch previous {
  | None => None
  | Some(previous) =>
    let wasWorking = previous.counts.running > 0 || previous.counts.retrying > 0
    let becameIdle = wasWorking && next.counts.running == 0 && next.counts.retrying == 0

    if hasNewIssueError(previous, next) {
      Some("attention")
    } else if becameIdle {
      Some("idle")
    } else {
      None
    }
  }
}

let playAudioNotification = kind => {
  switch kind {
  | "attention" => playTone(~frequencyValue=880.0, ~durationMs=180, ~oscillatorType="square", ~gainValue=0.08)
  | "idle" =>
    playTone(~frequencyValue=523.25, ~durationMs=140, ~oscillatorType="sine", ~gainValue=0.06)
    setTimeout(() => playTone(~frequencyValue=659.25, ~durationMs=160, ~oscillatorType="sine", ~gainValue=0.05), 120)
  | _ => ()
  }
}

let maybeEmitAudioNotification = (enabled, previous, next) => {
  if enabled {
    switch audioNotificationForTransition(previous, next) {
    | Some(kind) => playAudioNotification(kind)
    | None => ()
    }
  }
}
