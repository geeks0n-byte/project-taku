extends SceneTree
## Headless puzzle-logic smoke tests.
## Run: godot --headless --path . -s res://tests/run_logic_tests.gd
## Or:  powershell -File tools/run_logic_tests.ps1

const LogicTestRunner := preload("res://tests/logic_test_runner.gd")
const TestPuzzle := preload("res://tests/logic/test_puzzle.gd")
const TestSaveUi := preload("res://tests/logic/test_save_ui.gd")
const TestHints := preload("res://tests/logic/test_hints.gd")
const TestAchievements := preload("res://tests/logic/test_achievements.gd")
const TestIntegration := preload("res://tests/logic/test_integration.gd")
const TestSceneSmoke := preload("res://tests/logic/test_scene_smoke.gd")
const TestPlayGames := preload("res://tests/logic/test_play_games.gd")
const TestSession := preload("res://tests/logic/test_session.gd")
const TestAchievementManager := preload("res://tests/logic/test_achievement_manager.gd")

func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var r := LogicTestRunner.new()
	r.root = root
	TestPuzzle.run(r)
	TestSaveUi.run(r)
	TestHints.run(r)
	TestAchievements.run(r)
	TestIntegration.run(r)
	TestSceneSmoke.run(r)
	TestPlayGames.run(r)
	TestSession.run(r)
	TestAchievementManager.run(r)
	print("logic_tests: %d passed, %d failed" % [r.passed, r.failed])
	quit(1 if r.failed > 0 else 0)
