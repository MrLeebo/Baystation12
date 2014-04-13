/**
 * Implementation of a simple state machine class for structuring logic.
 *
 * ==== Example ====
 *
 * To create a state machine use the constructor, passing in the initial state.
 *
 *   // State machine for processing school applications
 *   var/datum/state_machine/M = new("pending")
 *
 * Use the "when" proc to add new event triggers. An associative list describes the transitions.
 *
 *   M.when("approve", list("pending"="approved"))
 *   M.when("deny", list("pending"="denied"))
 *
 * "any" is a special keyword that will transition from any state to the given state. Very useful for starting over.
 *
 *   M.when("reset", list("any"="pending"))
 *
 * You can designate callbacks that will trigger when the machine enters a given state.
 *
 *   M.on("denied", /proc/application_denied)
 *
 * You can add a callback that fires for any transition as well.
 *
 *   M.any(/proc/notify_all_changes)
 *
 * In your event code, you can run the "trigger" proc on the state machine.
 * "trigger" returns 1 if the trigger changed the machine's state and 0 otherwise.
 *
 *   M.trigger("approve")
 *
 * You can optionally pass a data parameter to the "trigger" proc. If the trigger succeeds,
 * the data will be forwarded to the callbacks that are triggered.
 *
 *   M.trigger("deny", list("reason"="Your score was too low."))
 *
 * A callback declaration should take the state machine as the first parameter and the optional
 * data parameter for the second:
 *
 *   proc/application_denied(datum/state_machine/M, data)
 *
 *     // "We're sorry. Your application is denied because: Your score was too low."
 *     usr << "<b>We're sorry.</b> Your application is [M.state] because: [data]"
 *     usr << "\red Better luck next year!"
 *
 * For an example of a more sophisticated state machine, see the "test_state_machine"
 * proc at the bottom of this script.
 */
/datum/state_machine
  var/state
  var/list/transitions_for = list()
  var/list/callbacks = list()

  New(initial)
    state = initial

  // Add an event trigger that can transition the state machine. "args" should be an associative list.
  proc/when(e, list/args)
    for(var/from in args)
      var/list/L = get_event_states(e)
      L[from] = args[from]

  // Add a callback when the state machine enters a given state.
  proc/on(state, callback)
    var/list/callbacks = get_callbacks(state)
    callbacks.Add(callback)

  // Add a callback that triggers on any state change.
  proc/any(callback)
    on("any", callback)

  // Trigger an event that might change the machine's state.
  // Returns 1 if the machine's state changed, 0 otherwise.
  // Optionally pass in a data parameter to send data to the
  // callbacks that are attached to this state.
  proc/trigger(e, data=null)
    var/new_state = get_transition(e)
    if (!new_state)
      return 0

    state = new_state
    for(var/cb in get_callbacks(state))
      call(cb)(src, data)

    for(var/cb in get_callbacks("any"))
      call(cb)(src, data)

    return 1

  // Returns a user-readable string describing this state machine.
  proc/describe()
    var/T = "state: [state]<br>"
    for(var/e in transitions_for)
      var/list/L = transitions_for[e]
      T += "transitions: [e] ([length(L)])<br>"
      for(var/from in L)
        T += "    [from] => [L[from]]<br>"

    return T

  // Implementation procs

  proc/get_transition(e)
    return transitions_for[e][state] || transitions_for[e]["any"]

  proc/get_callbacks(state)
    if (!callbacks.Find(state))
      callbacks[state] = list()

    return callbacks[state]

  proc/get_event_states(e)
    if (!transitions_for.Find(e))
      transitions_for[e] = list()

    return transitions_for[e]

// Can be executed with Advanced ProcCall to verify that this code works as expected.
// Hooray for ghetto unit testing?
proc/test_state_machine()
  usr << "<b>Running state machine tests...</b>"

  var/datum/state_machine/M = new("off")
  M.when("ignition", list("off"="park"))
  M.when("shift_up", list("park"="reverse", "reverse"="neutral", "neutral"="drive"))
  M.when("shift_down", list("drive"="neutral", "neutral"="reverse", "reverse"="park"))
  M.on("drive", /proc/_test_drive)
  M.any(/proc/_test_any)

  usr << "[usr], your car is ready!"
  usr << M.describe()

  ASSERT(M.state == "off")
  ASSERT(M.trigger("ignition"))
  ASSERT(M.state == "park")
  ASSERT(M.trigger("shift_up"))
  ASSERT(M.state == "reverse")
  ASSERT(M.trigger("shift_up"))
  ASSERT(M.state == "neutral")
  ASSERT(M.trigger("shift_up", "Jack"))
  ASSERT(M.state == "drive")
  ASSERT(!M.trigger("shift_up"))
  ASSERT(M.state == "drive")
  ASSERT(M.trigger("shift_down"))
  ASSERT(M.state == "neutral")

  usr << "\green <b>Passed!</b>"

proc/_test_drive(datum/state_machine/M, data)
  usr << "<b>Hit the road, [data]!</b>"

proc/_test_any(datum/state_machine/M, data)
  usr << "[usr] shifted into [M.state]."
