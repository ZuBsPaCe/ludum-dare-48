enum TileType {

	# Open and dirt must come first. See Map._check_diagonal_connections()
	OPEN,
	DIRT,

	ROCK,
	PRISON,
	MINION_START,
	MONSTER_START,
	START_PORTAL,
	END_PORTAL,
	PRISON_START
}
