
static func patch(path: String) -> void:
	var content := FileAccess.get_file_as_string(path)
	if content.is_empty():
		return

	if content.contains("AD0000000000000000000001"):
		return

	var local_ref_id := "AD0000000000000000000001"
	var product_dep_id := "AD0000000000000000000002"
	var build_file_id := "AD0000000000000000000003"

	if not content.contains("/* Begin XCLocalSwiftPackageReference section */"):
		content = (
			content
			. replace(
				"/* End PBXGroup section */",
				"/* End PBXGroup section */\n\n/* Begin XCLocalSwiftPackageReference section */\n/* End XCLocalSwiftPackageReference section */"
			)
		)

	if not content.contains("/* Begin XCSwiftPackageProductDependency section */"):
		content = (
			content
			. replace(
				"/* End XCLocalSwiftPackageReference section */",
				"/* End XCLocalSwiftPackageReference section */\n\n/* Begin XCSwiftPackageProductDependency section */\n/* End XCSwiftPackageProductDependency section */"
			)
		)

	var local_ref_def := (
		"		"
		+ local_ref_id
		+ ' /* XCLocalSwiftPackageReference "admob_spm" */ = {\n			isa = XCLocalSwiftPackageReference;\n			relativePath = "admob_spm";\n		};\n'
	)
	content = content.replace(
		"/* End XCLocalSwiftPackageReference section */",
		local_ref_def + "/* End XCLocalSwiftPackageReference section */"
	)

	var product_dep_def := (
		"		"
		+ product_dep_id
		+ " /* PoingGodotAdMobDeps */ = {\n			isa = XCSwiftPackageProductDependency;\n			package = "
		+ local_ref_id
		+ ' /* XCLocalSwiftPackageReference "admob_spm" */;\n			productName = "PoingGodotAdMobDeps";\n		};\n'
	)
	content = content.replace(
		"/* End XCSwiftPackageProductDependency section */",
		product_dep_def + "/* End XCSwiftPackageProductDependency section */"
	)

	var build_file_def := (
		"		"
		+ build_file_id
		+ " /* PoingGodotAdMobDeps in Frameworks */ = {isa = PBXBuildFile; productRef = "
		+ product_dep_id
		+ " /* PoingGodotAdMobDeps */; };\n"
	)
	content = content.replace(
		"/* Begin PBXBuildFile section */", "/* Begin PBXBuildFile section */\n" + build_file_def
	)

	if content.contains("$spm_packages"):
		content = content.replace(
			"$spm_packages",
			local_ref_id + ' /* XCLocalSwiftPackageReference "admob_spm" */'
		)
	elif content.contains("packageReferences = ("):
		content = content.replace(
			"packageReferences = (",
			(
				"packageReferences = (\n				"
				+ local_ref_id
				+ ' /* XCLocalSwiftPackageReference "admob_spm" */,'
			)
		)
	else:
		content = (
			content
			. replace(
				"productRefGroup =",
				(
					"packageReferences = (\n				"
					+ local_ref_id
					+ ' /* XCLocalSwiftPackageReference "admob_spm" */,\n			);\n			productRefGroup ='
				)
			)
		)

	if content.contains("packageProductDependencies = ("):
		content = content.replace(
			"packageProductDependencies = (",
			(
				"packageProductDependencies = (\n				"
				+ product_dep_id
				+ " /* PoingGodotAdMobDeps */,"
			)
		)
	else:
		content = content.replace(
			"buildRules = (",
			(
				"packageProductDependencies = (\n				"
				+ product_dep_id
				+ " /* PoingGodotAdMobDeps */,\n			);\n			buildRules = ("
			)
		)

	var framework_section_start := content.find("isa = PBXFrameworksBuildPhase;")
	if framework_section_start != -1:
		var files_start := content.find("files = (", framework_section_start)
		if files_start != -1:
			content = content.insert(
				files_start + 9,
				"\n				" + build_file_id + " /* PoingGodotAdMobDeps in Frameworks */,"
			)

	content = content.replace("$spm_package_refs", "")
	content = content.replace("$spm_package_products", "")

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		print("AdMob: Patched project.pbxproj with SPM dependencies")
