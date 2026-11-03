# v3 field clearance semantics

The 8 px margin first appears in this v3 candidate. It is a conservative cell-centre navigation margin, not an existing player collision radius. Actor.move_along updates a position point; keyboard movement uses World.passable. Existing solid-wall checks still use Rect2.grow(3), unchanged. Both actual movement methods retain the same wall, water and field-surface boundary.

Short correction diff:
- before: walkable(at) always called blocked_by_field with margin 8, including keyboard feet and the self-check's interpolated feet.
- after: walkable(at, nav_clearance=false); grid creation explicitly calls walkable(at,true); normal feet use the actual surface boundary. blocked_by_field uses margin 8 only for nav_clearance=true. This is not equivalent to deleting the field test: points outside visible path surfaces remain blocked.

The first self-check incorrectly required every interpolated foot to be a valid grid centre. It reported three paths at the extra 8 px guard, despite no foot outside the actual surface. The final check samples each segment at 4 positions and keeps solid-wall, river and actual field-boundary checks. Candidate nav is still generated with 8 px centre clearance. C3 independently samples actual Actor movement; its assertions/files were not edited.

field-clearance-cases.json contains six focused counterexamples: L corner outside the path; road edge outside; position inside road but within the extra grid guard; unchanged wall 3px buffer; water even when a drawn surface overlaps; and an unsafe corner segment whose intermediate feet are rejected. All pass. This is C2 focused verification, not C3 acceptance or OS playtesting.
