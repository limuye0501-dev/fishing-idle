# v5 progress (goal: 80%+ match to reference)
Reference: store asset 694d119b...jpg (pink-gold sunset, painted toy boat close 3/4 view).
## Plan
- [x] A. Sea shader: saturated turquoise, wave detail, foam crests, bow wave/V wake/hull ring, fix square specks (sparkle cells were square)
- [x] B. Sky: new painted skies (dusk strong pink-gold + sun disc), sun-glitter path, warmer light, grading; day/night distinct
- [x] C. Camera close 3/4, boat larger; UI declutter (collapsible rail, smaller minimap)
- [ ] D. Blender: textured materials (wood grain, worn paint, rope, rivets), deck clutter, bevels, bake atlas, USDZ
- [ ] E. Workflow video filename v5; collect screens/video/compare
## Log
- Step1 (commit "v5 step1"): new AI-painted Sky_dusk/day/night.jpg (horizon at 89%), sky art sun anchored at 30% screen; sea shader rewrite (wave height shading, crest foam, round sparkles in sun path, bow V, wake, hull ring); camera (0.3,5,10), yaw 0.55; warmer light, sat 1.18; collapsible rail + 92pt minimap; workflow video -> gameplay-v5-zh.mov. Next: check CI screenshots, then Blender (D).
