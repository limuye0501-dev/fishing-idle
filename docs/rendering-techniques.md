# Stylized / cozy sea rendering — notes (v6)
Sources: Wind Waker/Sea of Thieves/Genshin GDC-style breakdowns, Catlike Coding (Gerstner waves), Unity/UE stylized water tutorials, Apple SCNShadable docs.

## Techniques
- **Gerstner waves**: sum of 3–5 directional waves, P.xz -= Q·A·D·sin(θ), P.y = A·cos(θ); analytic normals. In SceneKit: `.geometry` modifier on `_geometry.position/normal` (needs dense grid), or fake via normals only in `.surface` (what we do — cheaper).
- **Depth/distance color gradient**: shallow→deep by distance from ship/camera; Fresnel `pow(1-N·V,4..5)` mixes in sky/horizon colour toward horizon. Pastel look = low-saturation teal + strong horizon colour blend.
- **Sun glitter path**: physically = reflected-ray·sunDir with high-power spec over noisy normals. Stylized = screen/azimuth-space column under the sun (gaussian in x, widening toward camera) × ripple noise, added *additively at the very end* (`.fragment` modifier, `_output.color.rgb += ...`) so fog/constant lighting don't wash it; HDR values >1 feed bloom → soft glow.
- **Toon / soft ramp shading**: N·L remapped through a smooth ramp (`smoothstep(-0.2,0.6,NdotL)`) or ramp texture; wrap lighting `(NdotL+w)/(1+w)` for soft cozy shadows. SceneKit: `.lightingModel = .physicallyBased` + `.lightingModelFragment` modifier, or `.constant` + manual.
- **Rim light**: `pow(1-N·V, 3) * rimColor` (warm sunset pink/gold) — separates chibi characters from background.
- **Gradient sky**: painted skybox or 3-stop vertical gradient (zenith/mid/horizon) + sun disc + halo; fog colour = horizon colour so sea melts into sky.
- **Tonemap / grading**: ACES/filmic shoulders keep highlights soft; SceneKit `SCNCamera.wantsHDR`, `whitePoint`, `contrast`, `saturation`, `colorGrading.contents` (LUT strip image). Cozy look = low contrast, slight lifted blacks, warm highlights.
- **Soft bloom**: lower threshold (~0.7), larger blur radius, moderate intensity; makes glitter and sun glow.

## Applied in v6
- `SeaShader.fragment`: additive gold glitter column under painted sun (ndc x −0.40), ripple-broken, HDR → bloom.
- Softer palette: pastel teal shallow/deep, fg darkening reduced, camera contrast 0.04, saturation 1.04, bloom 0.75/0.72/20.
- Captain scale 1.5 → 2.2.

## Applied in v8 (sea rewrite)
- Gerstner sum (6 waves, 0.8–9 m wavelengths, deep-water dispersion ω=√(gk)) with real vertex displacement on an 84 m, 168×168 near mesh (edges fade to flat; flat 600 m far plane underneath). Same wave set evaluated per-pixel for analytic normals (Sea of Thieves / GPU Gems ch.1 approach).
- Tileable procedural detail normal map sampled at 3 scrolling scales (macro 0.023, mid 0.11, micro 0.37 /m) — breaks tiling, adds sparkle detail near camera.
- Colour: view-angle depth gradient shallow→deep, crest brighten / trough darken, subsurface tint on back-lit crests (Genshin/AC-style SSS fake), Schlick Fresnel sky reflection with horizon→zenith tint, crest whitecaps from height + noise, horizon fog to sky colour.
- Kept: screen-space golden glitter path under the sun, hull foam ring, bow churn, wake.
