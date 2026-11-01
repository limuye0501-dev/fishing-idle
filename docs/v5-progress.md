# v5 progress (goal: 80%+ match to reference)
Reference: store asset 694d119b...jpg (pink-gold sunset, painted toy boat close 3/4 view).
## Plan
- [x] A. Sea shader: saturated turquoise, wave detail, foam crests, bow wave/V wake/hull ring, fix square specks (sparkle cells were square)
- [x] B. Sky: new painted skies (dusk strong pink-gold + sun disc), sun-glitter path, warmer light, grading; day/night distinct
- [x] C. Camera close 3/4, boat larger; UI declutter (collapsible rail, smaller minimap)
- [x] D. Blender: textured materials (wood grain, worn paint, rope, rivets), deck clutter, bevels, bake atlas, USDZ
- [ ] E. Workflow video filename v5; collect screens/video/compare
## Log
- Step1 (commit "v5 step1"): new AI-painted Sky_dusk/day/night.jpg (horizon at 89%), sky art sun anchored at 30% screen; sea shader rewrite (wave height shading, crest foam, round sparkles in sun path, bow V, wake, hull ring); camera (0.3,5,10), yaw 0.55; warmer light, sat 1.18; collapsible rail + 92pt minimap; workflow video -> gameplay-v5-zh.mov. Next: check CI screenshots, then Blender (D).
- Step2 (commit "v5 step2"): tools/blender/texmats.py (procedural wood grain/planks via brick tex, worn paint w/ pointiness edge wear, rope, metal); ship.py uses it, wooden mast/booms, rivet row, baskets/net pile/drums/tarp/fenders/coil2; bake_export.py RES=4096 JPEG atlas, captain arg '-' skips captain (Captain.usdz unchanged). Rebuild: blender -b -P ship.py -- /tmp/v5 ; RES=4096 blender -b -P bake_export.py -- /tmp/v5/ship_raw.blend - /tmp/v5/out ; cp out/Ship.usdz App/Resources/Models/. Closeup: docs/ship-v5-closeup.png
- Step3: yaw -0.62 (bow toward camera-right), camera (0.1,5.3,11); dusk fog 110-420 so sun path visible; stronger glitter; darker night sea. Check CI shots after.
- Step4 (delivery): collected run 41251567444 (step3, green) screens -> /workspace/FishingIdle-screens-v5, mp4, compare-reference.png. Uncommitted WIP tweaks (SeaShader/ShipScene/Textures/ship.py) left unverified in working tree. Remaining: sun disc not visible in dusk frame, wake/bow-wave subtle, sea foam a bit washed.
- Step5 (v5.1): kept WIP tweaks (fixed 'band' used-before-declared in SeaShader); yaw -0.85, cam (0.2,4.7,9.6); painted dusk sun disc+glow at 30%; darker/saturated near-camera sea, less fresnel wash; stronger hull foam, longer bow V, bolder wake. Next: verify CI dusk shot.
- Step5 result: CI 41253362792 green; sun disc visible. Remaining: foreground still bright cyan, no glitter column under sun, bow spray weak, no captain on deck, net white/not rope-brown.
