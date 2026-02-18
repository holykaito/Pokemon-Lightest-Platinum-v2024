module PBEffects
  GoodLuck      	= 6700 	# Used to determine if bonus money should be given.
  VictoryStarEvo	= 6701	# Used to track Victory Star Mega Evolutions
  RageBaited		= 6702	# Used to decide if a battler can be baited again
  BeastMode			= 6703	# Tracks turns of beast mode
  BoulderBarrier	= 6704	# Tracks protects for damage next turn.
  HesSafe			= 6705	# Tracks if the user would have fainted to a recoil move.
  QuickStrike		= 6706	# Has gone first in battle!
  FirstMove			= 6707  # Is the first move for this mon!
end

#-------------------------------------------------------------------------------
# New effects and values to be added to the debug menu.
#-------------------------------------------------------------------------------
module Battle::DebugVariables
  BATTLER_EFFECTS[PBEffects::GoodLuck]     		 	= { name: "Should double money?",                		default: false }
  BATTLER_EFFECTS[PBEffects::VictoryStarEvo]      	= { name: "Did Victory Start Mega Evolve?",             default: 0 }
  BATTLER_EFFECTS[PBEffects::RageBaited]      		= { name: "Has been rage baited?",              	 	default: false }
  BATTLER_EFFECTS[PBEffects::BeastMode]      		= { name: "Turns of BeastMode Counter.",             	default: 0 }
  BATTLER_EFFECTS[PBEffects::BoulderBarrier]      	= { name: "Had a successful protect?",              	default: false }
  BATTLER_EFFECTS[PBEffects::HesSafe]      			= { name: "Fainted to a recoil move?",              	default: [] }
  BATTLER_EFFECTS[PBEffects::QuickStrike]      		= { name: "Went first in battle?",              		default: [] }
  BATTLER_EFFECTS[PBEffects::FirstMove]      		= { name: "Is it the first move for this mon?",         default: false }
end