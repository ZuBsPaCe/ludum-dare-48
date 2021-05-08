enum NodeType {
	# Minions need to pass through the next portal
	PORTAL,

	# For the noobies.
	TUTORIAL,

	# Minions are autonomous. Protect them.
	ESCORT,

	# Get the king out of the prison.
	RESCUE,

	# You are a single minion or the king. All others are imprisoned.
	PRISON,

	# Stay put and survive the attack waves
	DEFEND,

	# Buy some beer.
	MERCHANT,

	# Bye Bye.
	HELL
}
