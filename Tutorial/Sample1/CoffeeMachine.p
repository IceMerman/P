// hardware abstraction layer represented by events and functions.
event DOOR_OPENED;
event DOOR_CLOSED;
event UNKNOWN_ERROR;
event EXPRESSO_BUTTON;
event STEAMER_ON;
event STEAMER_OFF;
event EXPRESSO_COMPLETE;

// this function returns true if something is open such that machine cannot safely operate.
fun CheckIsOpen() : bool { return false; }
fun CheckWaterLevel() : bool { return false; }
fun CheckBeans() : bool { return false; }
// turn on red light
fun ShowError() {}
// turn on heating element
fun BeginHeating() {}

// this function returns true if heating is complete.
fun CheckHeat() : bool { return false; }

// star the expresso function
fun StartExpresso() {}

// start the steamer 
fun StartSteamer() {}

// stop the steamer 
fun StopSteamer() {}

// stop all functions
fun EmergencyStop() {}

// internal events
event ReadyDoorOpened;

// Now for the the actual state machine
machine CoffeeMachine
{
    // fields
    var timer: TimerPtr;

    // states
    start state Init
    {
        entry
        {
            timer = CreateTimer(this);
            if (CheckIsOpen() || !CheckWaterLevel() || !CheckBeans()) {
                goto Error;
            }
            goto WarmingUp;
        }

        ignore EXPRESSO_BUTTON;
        ignore STEAMER_ON;
        ignore STEAMER_OFF;
    }

    state WarmingUp {
        entry {
            StartTimer(timer, 1000);
            BeginHeating();
        }
        on TIMEOUT do
        {
            if (CheckHeat()) {
                goto Ready;
            } else {
                StartTimer(timer, 1000);
            }
        }
        on DOOR_OPENED push DoorOpened;
        on UNKNOWN_ERROR goto Error;
        ignore EXPRESSO_BUTTON;
        ignore STEAMER_ON;
        ignore STEAMER_OFF;
    }
    
    state Ready {
        entry {
            if (CheckIsOpen()){
                raise ReadyDoorOpened;
            }
        }
        on DOOR_OPENED push DoorOpened;
        on UNKNOWN_ERROR goto Error;
        on EXPRESSO_BUTTON push MakeExpresso;
        on STEAMER_ON push MakeSteam;
        on ReadyDoorOpened push DoorOpened;
    }

    state MakeExpresso {
        entry {
            StartExpresso();   
        }
        on EXPRESSO_COMPLETE do { pop; }
        on UNKNOWN_ERROR goto Error;
        on DOOR_OPENED do {
            EmergencyStop();
            pop;
        }
        // Can't make steam while we are making expresso
        ignore STEAMER_ON;
        ignore STEAMER_OFF;
    }

    state MakeSteam {
        entry {
            StartSteamer();
        }
        on STEAMER_OFF  do { pop; }
        on UNKNOWN_ERROR goto Error;
        on DOOR_OPENED do {
            EmergencyStop();
            pop;
        }
        ignore STEAMER_ON;
        // can't make expresso while we are making steam
        ignore EXPRESSO_BUTTON;
    }

    state DoorOpened {
        entry{
            // do not respond to any user input
            EmergencyStop();
            ShowError();
        }
        on DOOR_CLOSED  do { pop; }
        on UNKNOWN_ERROR goto Error;
        ignore EXPRESSO_BUTTON;
        ignore STEAMER_ON;
        ignore STEAMER_OFF;
    }
    
    state Error {
        entry {
            // do not respond to any user input
            ShowError();
        }
        ignore DOOR_OPENED;
        ignore DOOR_CLOSED;
        ignore EXPRESSO_BUTTON;
        ignore STEAMER_ON;
        ignore STEAMER_OFF;
    }
}