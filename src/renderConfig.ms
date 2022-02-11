global dyObjList = #()
global parentlist = #()
global  customerModelLibrary = "" -- path to component model lib
global projectRootFolder = "" -- path to vcurrent project root


fn dyStandardRenderElemenrs = (
		dyCreateRenderElement VrayBackground "VrayBackground"
		dyCreateRenderElement VraySpecular "VraySpecular"
		dyCreateRenderElement VrayReflection "VrayReflection"
		dyCreateRenderElement VrayRawReflection "VrayRawReflection"
		dyCreateRenderElement VrayRefraction "VrayRefraction"
		dyCreateRenderElement VrayRawRefraction "VrayRawRefraction"
		dyCreateRenderElement VrayRawLighting "VrayRawLighting"
		dyCreateRenderElement VrayGlobalIllumination "VrayGlobalIllumination"
		dyCreateRenderElement VrayShadows "VrayShadows"
		dyCreateRenderElement VrayDiffuseFilter "VrayDiffuseFilter"
		dyCreateRenderElement VraySamplerInfo "VraySamplerNormals"
		dyCreateRenderElement VRayTotalLighting "VRayTotalLighting"
		dyCreateRenderElement VrayNormals "VrayNormals"
		dyCreateRenderElement VRayWireColor "VRayWireColor"
        dyCreateRenderElement VRayRawRefraction "RawRefraction"
        dyCreateRenderElement VRayRefractionFilter "RefractionFilter"
		dyCreateRenderElement VRaySelfIllumination "VRaySelfIllumination"
		AddZdepth "ZDepth"
		-- change to normal vector
		element = dyrenderElementByName "VraySamplerNormals"
		element.type = 1 -- normal vector
		dyRenderElementsFromLights()
		dyAddAOPass()
)


fn kill_dup_mats =
	(
	scene_mats = dy_get_scene_materials()
	scene_mats_names = for i in scene_mats collect i.name

	for i in $* do
		(
		if i.material != undefined then
			(
			w = finditem scene_mats_names i.material.name
			i.material = scene_mats[w]
			)
		)
	)


fn getNodesRoot nodes =
	(
	parentlist = #()
	for theNode in nodes do (
	appendifunique parentlist ( getNodeRoot theNode	)
	)
	return parentlist
)


function getNodeRoot theNode =
(
	local theParent = theNode.parent
	while (theParent != undefined) do
	(
	theNode = theParent
	theParent = theNode.parent
	)
	return theNode
)


fn findFile root pattern = (

	dir_array = GetDirectories (root+"/*")
	for d in dir_array do(
		join dir_array (GetDirectories (d+"/*"))
		)

	my_files = #()

	for f in dir_array do (
		join my_files (getFiles (f + pattern))
		)

	return my_files[1]
)


fn loadEnviroment enviroment = (
	scenefolder = customerModelLibrary + @"_Environments\"  +enviroment +"\\"
	scenepath = scenefolder+ enviroment+".max"
	loadMaxfile scenepath quiet:true
	)


fn loadproduct product = (
	redrawViews()
	sleep 2
	print ("loadproduct " + product)
	print customerModelLibrary
		try(
			productPath = findFile customerModelLibrary  product
			print ("merging product " + productPath)
			mergeMAXFile  productPath #mergeDups #useSceneMtlDups #select quiet:true
			print "successfully merged"
			global dyObjList  = (selection as array)
			appendToSet()
		)
		catch(
			print ("ERROR! Could not find product " + product)
			global dyObjList = #($nullDummy)
			)

)


fn alignProduct  InsertionPoint moveUp = (
	redrawViews()
	sleep 2
	product = dyObjList -- may findParent
	if (units.SystemType == #centimeters) then (moveup= (moveUp/10)  )
	if (units.SystemType == #meters) then (moveup= ( moveUp/100)  )
	if (units.SystemType == #inches) then (moveup= (( moveUp/10)*2.54)  )

	print "Aligning"
	print product
	productDummy = (getNodesRoot dyObjList)[1]
	print productDummy.name

	InsertionPointDummy = execute("$"+InsertionPoint)

	--productDummy.transform = InsertionPointDummy.transform
	productDummy.pos = InsertionPointDummy.pos
	productDummy.rotation.z_rotation= InsertionPointDummy.rotation.z_rotation
	productDummy.pos.z  = productDummy.pos.z + moveUp
	redrawViews()
	sleep 2
)

fn resetScene = (
	print "Resettting scene..."
	--resetMaxFile #noPrompt
	selectionSets["heroModels"] = #()
	)

fn switchMaterial  oldMaterialName MaterialName  = (
	dySwapMaterials dyObjList  oldMaterialName MaterialName
)

fn appendToSet = (
	if (selectionSets["heroModels"] == undefined) then (
		selectionSets["heroModels"] = #()
		)

	ls = #()
	for  i in selectionSets["heroModels"]  do (try(append ls i)catch())
	ls = (join ls dyObjList )
	selectionSets["heroModels"]  = ls
	)

fn deleteHeroModels = (
	try(
	print "cleaning up..."
	--delete selectionSets["heroModels"]
	)catch()
	)



fn renderConfig task rendername renderRes:#Full saveRenderfile:True skipExistingExrs:True renderType:#BackBurner =  (
	print "Rendering!"

	-- RenderElements
	reElms  = dyRenderElementstoList()
	local heromodels = #()

	for  i in selectionSets["heroModels"]  do (try(append heromodels i)catch())

	--  Materials and render elements
	dykill_dup_mats()
	print (dy_get_scene_materials())
	dyUpdateMaterials heromodels
	dyOBJRenderElementsForObjects heromodels
	dyStandardRenderElemenrs()
	dyCreateRenderElement VrayAlpha rendername
	print "Removing duplicate materials...."
	print (dy_get_scene_materials())
	dykill_dup_mats()
	print "\n\n"

	dyMaterialRenderElementsForObjects heromodels
	--  render
	maxFolder = projectRootFolder + task + "\\Max\\Scenes\\"
	dyDoesFolderExist maxFolder create:true
	outputFolder = projectRootFolder + task + "\\Max\\RenderOutput\\"
	outputFolder = dyCreateDateFolder outputFolder

	vr=renderers.current
	vr.system_distributedRender = false
	vr.output_saveRawFile = true
	print (outputFolder + rendername  + ".exr"	)
	vr.output_rawFileName =  (outputFolder + rendername  + ".exr"		)



	h = renderHeight
	w = renderWidth
	aspect = w/ h
--	if (renderRes == #Full) then ()
	if (renderRes == #Preview) then (
		renderWidth = 600
		renderHeight =  600.0 / aspect
	)
	if (renderRes == #ThumbNail) then (
		renderWidth = 200
		renderHeight =  200.0 / aspect
	)


	if (saveRenderfile ) then (
		print "\nSAVE\n"
		print (maxFolder+rendername+".max")
		saveMaxfile (maxFolder+rendername+".max")
	)

	if (renderType == #BackBurner) then (
		if not (saveRenderfile ) then (
		saveMaxfile (maxFolder+rendername+".max")
		)
		dyStartNetRender()
	)
	if (renderType == #DR) then (
		vr.system_distributedRender = true
		dyInitRender outputFolder rendername skipExistingExrs:skipExistingExrs dr:True --dr skipExistingExrs
	)
	if (renderType == #Normal) then (
		vr.system_distributedRender = false
		dyInitRender outputFolder rendername skipExistingExrs:skipExistingExrs dr:false --dr skipExistingExrs
	)

	dyStartNetRender()
	print ("Rendered: " +  outputFolder + rendername  + ".exr"	 )
	render elements cleanup
	newelements = dyFindRenderElementsNotInList reElms
	re = maxOps.GetCurRenderElementMgr()
	for element in newelements do (
		re.RemoveRenderElement element
	)
)