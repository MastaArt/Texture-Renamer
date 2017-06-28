/*  
[INFO] 

NAME = Material Renamer
VERSION = 1.0.0
AUTHOR = Vasily Lukyanenko
DEV = 3DGROUND
CUSTOMER = Andrew Andreyuk
SKYPE = notfun1
HELP = 

[INSTALL]

MACRO=TextureRenamer
CAT=3DGROUND
TEXT=Texture Renamer
ICON=#("PhysX_Main", 30)

[1.0.0]

* First release =

[ABOUT]

Prepare scene for import to Maya=
Rename texture files and relink according mesh name=

[TEST]

[SCRIPT]
*/	


try(closeRolloutFloater rTextureRenamer)catch()
global rTextureRenamer = newRolloutFloater "Material Renamer" 280 300

global _STEP1
global BitmapTypes = #(Bitmaptexture, CoronaBitmap)

fn trim s c: " " = trimRight (trimLeft s c) c

fn getScriptInfo s releaseInfo: "" =
(		
	if(releaseInfo != "") do
	(
		r = getINISetting s releaseInfo
		return r
	)
	
	v = getINISetting s "INFO" "VERSION"
	a = getINISetting s "INFO" "AUTHOR"
	n = getINISetting s "INFO" "NAME"
	o = getINISetting s "ABOUT"
	c = getINISetting s "INFO" "DEV"
	h = getINISetting s "INFO" "HELP"
	
	r = for i in (getINISetting s) where i != "ABOUT" and i != "SCRIPT" and i != "COPY" collect i
	
	return #(n, a, v, o, r, c, h)
)

fn showTooltip c t =
(
	toolTip = dotnetobject "System.Windows.Forms.ToolTip"
	toolTip.SetToolTip c t   
	--toolTip.Active = true    
	toolTip.isBalloon = true
	toolTip.InitialDelay = 100
	toolTip.AutoPopDelay = 500
	toolTip.ReshowDelay = 50
	toolTip.ToolTipTitle = "Warning!"
	toolTip.Show t c 3000	
	toolTip.ToolTipIcon = (dotnetclass "System.Windows.Forms.ToolTipIcon").Warning
)

fn getFullPath p = 
(	
	if(doesFileExist p) do return p
	
	return mapPaths.getFullFilePath (filenameFromPath  p)
)

fn getStrinNumber n c:3 =
(
	n = n as string
	
	if(n.count < c) do
	(
		d = c - n.count
		
		s = ""
		
		for i in 1 to d do s += "0"
		return s + n
	)
	
	return n
)

fn stripName n = trimRight n "_0123456789"

fn checkSlot b1 b2 = 
(	
	if(b1 == undefined or b2 == undefined) do return false
	refs.dependencyLoopTest b1 b2
)


fn getDependence mat =
(	
	outTexMaps = #()
	fn getSubMap m =
	(				
		t = #()
		
		if(m == undefined) do return t
		
		c = 0
		try(c = getNumSubTexmaps m)catch(c = 0)
		for o in 1 to c do
		(
			a = getSubTexmap m o
		
			appendIfUnique t a			
			join t (getSubMap a)
			join outTexMaps t			
		)
		
		return t
	)
	
	fn getMaps mat =
	(
		
			m = #()
			if(classOf mat == MultiSubMaterial) then m = mat else m = #(mat)
			
			for j in m where j != undefined do
			(
				for o in 1 to (getNumSubTexmaps j) do
				(
					a = getSubTexmap j o
					appendIfUnique outTexMaps a
					join outTexMaps (getSubMap a)
				)
			)								
		
	)
	
	getMaps mat
	
	return for i in outTexMaps where i != undefined collect i
)


fn renameMaterialsAsMeshes =
(
	oldMatNames = #()
	oldMats = #()

	for i in objects where i.material != undefined do 
	(
		n = stripName i.name
		m = i.material
				
		f = findItem oldMats m
		if(f != 0 and oldMats[f].name != n) do 
		(
			nm = copy i.material
			nm.name = n
			i.material = nm
			
			continue 
		)
		
		append oldMatNames n
		append oldMats m
		
		i.material.name = n
		
		d = getDependence i.material
		for i in 1 to d.count where d[i] != undefined do d[i].name = n + "_" + i as string
	)
)

fn batchBakeColorCorrection f size =
(
	cc = for i in getClassInstances Color_Correction where i != undefined collect i
	cc = makeUniqueArray cc
	
	
	progressStart "Bake CC..."
	escapeEnable
	
	for i in 1 to cc.count do
	(		
		fname = f + "Bake_CC_" + i as string + ".jpg"
		print fname
		
		b = renderMap cc[i] size: [size, size] display: false
		b.filename = fname	
		save b
		
		bm = BitmapTex filename: fname name: (getFileNameFile fname)
				
		replaceInstances cc[i] bm
		
		progressUpdate (100.0 * i / cc.count)						
		if(getProgressCancel() == true) do exit	
	)
	
	progressEnd()	
)


rollout _STEP1 "Material Renamer"
(
	group "Bake ColorCorrection:"
	(
		spinner spnSize  "Size: " range: [256, 8192, 4096] type: #integer fieldWidth: 50 align: #left across: 2
		label lblPX " px" align: #left offset: [-30, 0]
		edittext edtPath "" readOnly: true height: 25
		button btnSelectPath "Select Path"
	)
	
	button btnStartRename "Start Rename" height: 35 width: 235
	
	fn renameTextures scope iCnt: 1 = 
	(
		if(maxFilePath == "") do return 0
		
		oldTex = #()
		oldTexPaths = #()
		errorTex = #()
		newTexPaths = #()
		
		toRename = #()
		
		for i in scope where i.material != undefined do
		(
			for type in BitmapTypes where classOf type == textureMap do 
			(	
				for b in getClassInstances type target: i where (b != undefined and b.filename != undefined and b.filename != "") do
				(
					postfix = ""
					a = refs.dependents b
					j = a[5]
					
					if(classOf j == Mix) do  j = (refs.dependents j)[9]																				
					if(classOf j == ColorCorrection) do j = (refs.dependents j)[7]													
					if(classOf j == Falloff) do j = (refs.dependents j)[8]													
										
					if(classOf j == VrayMtl) do
					(
						postfix = case of
						(
							(checkSlot j.texmap_diffuse b): "_diffuse"
							(checkSlot j.texmap_reflection b): "_reflection"
							(checkSlot j.texmap_refraction b): "_refraction"
							(checkSlot j.texmap_reflectionGlossiness b): "_glossiness"
							(checkSlot j.texmap_displacement b): "_displacement"
							(checkSlot j.texmap_translucent b): "_translucent"
							(checkSlot j.texmap_environment b): "_environment"
							(checkSlot j.texmap_hilightGlossiness b): "_highlight_glossiness"
							(checkSlot j.texmap_opacity b): "_opacity"
							(checkSlot j.texmap_roughness b): "_roughness"
							(checkSlot j.texmap_anisotropy b): "_anisotropy"
							(checkSlot j.texmap_reflectionIOR b): "_ior"
							(checkSlot j.texmap_bump b): "_bump"
							default: ""
						)
					)
									
					if(findItem oldTex b != 0) do continue
					if(not doesFileExist b.filename) do append errorTex b
					
					f = b.filename
					p = getFilenamePath f
					ext = getFilenameType f				
					new = p + (stripName i.name)  +"_" + (getStrinNumber iCnt) as string + postfix + ext
					
					ep = findItem oldTexPaths f 
					if(ep == 0) then
					(																				
						iCnt += 1
						
						append toRename #(b, new, f, #rename, i.name)
						
					) else
					(
						append toRename #(b, newTexPaths[ep], f, #change, i.name)
					)
									
					append oldTex b
					append oldTexPaths f
					append newTexPaths new
				)	
			)
		)

		iCnt = 0
		print toRename
		out = edtPath.text + @"\"
		/*
		for i in toRename do
		(
			b = i[1]
			n = i[2]
			f = i[3]
			
			j = out + filenameFromPath n
			
			b.filename = j
			b.name = getFileNameFile n
			if(i[4] == #rename) do 
			(
				--renameFile f n
						
				copyFile f j
				iCnt += 1
			)
		)*/
		
		
		return iCnt
	)

	
	on btnSelectPath pressed do
	(
		f = getSavepath caption: "Select Path"
		if(f == undefined) do return false
		
		edtPath.text = f
	)
	
	on btnStartRename pressed do
	(
		f = edtPath.text + "\\"
		if(f.count < 3 or not doesFileExist f) do return messageBox "Please select path!" title: "Warning!"
		
		renameMaterialsAsMeshes()
		batchBakeColorCorrection f spnSize.value	
	)
)

rollout _rAbout "About" 
(
	label lblName "" 
	label lblVer "" 
	
	label lblAuthor "" height: 30
	label lblCopy ""  height: 30
	
	local c = color 200 200 200 
	hyperLink href1 "http://3dground.net/" address: "http://3dground.net/" align: #center hoverColor: c visitedColor: c offset: [0, 20]
	
	on _rAbout open do
	(		
		i = getScriptInfo (getThisScriptFilename())
			
		lblName.caption = i[1]
		lblAuthor.caption = i[2]
		lblVer.caption = i[3]
		lblCopy.caption = i[6]
	)
)

addRollout _STEP1 rTextureRenamer 
addRollout _rAbout rTextureRenamer rolledUp:true