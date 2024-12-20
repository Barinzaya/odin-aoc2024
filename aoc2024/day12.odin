package aoc2024

import "core:fmt"
import "core:strings"
import "core:testing"
import "core:time"

day12 :: proc (input: string) {
	t := time.tick_now()

	p1, p2 := day12_solve(input)
	solve_dur := time.tick_lap_time(&t)

	fmt.println("Solved in", solve_dur)
	fmt.println("Part 1:", p1)
	fmt.println("Part 2:", p2)
}

day12_solve :: proc (input: string) -> (p1: int, p2: int) {
	Neighbor :: enum u8 { N, NE, E, SE, S, SW, W, NW }

	Region :: struct {
		area, perimeter, sides: u32,
	}

	get_cell :: #force_inline proc (input: string, i: int) -> u8 {
		return input[i] if uint(i) < uint(len(input)) else 0
	}

	// precomputed--see day12_clusters
	@(static, rodata)
	cluster_scores := [256]u8 {
		0x44, 0x23, 0x44, 0x23, 0x23, 0x22, 0x23, 0x12, 0x44, 0x23, 0x44, 0x23, 0x23, 0x22, 0x23, 0x12,
		0x23, 0x02, 0x23, 0x02, 0x22, 0x21, 0x22, 0x11, 0x23, 0x02, 0x23, 0x02, 0x12, 0x11, 0x12, 0x01,
		0x44, 0x23, 0x44, 0x23, 0x23, 0x22, 0x23, 0x12, 0x44, 0x23, 0x44, 0x23, 0x23, 0x22, 0x23, 0x12,
		0x23, 0x02, 0x23, 0x02, 0x22, 0x21, 0x22, 0x11, 0x23, 0x02, 0x23, 0x02, 0x12, 0x11, 0x12, 0x01,
		0x23, 0x22, 0x23, 0x22, 0x02, 0x21, 0x02, 0x11, 0x23, 0x22, 0x23, 0x22, 0x02, 0x21, 0x02, 0x11,
		0x22, 0x21, 0x22, 0x21, 0x21, 0x40, 0x21, 0x30, 0x22, 0x21, 0x22, 0x21, 0x11, 0x30, 0x11, 0x20,
		0x23, 0x22, 0x23, 0x22, 0x02, 0x21, 0x02, 0x11, 0x23, 0x22, 0x23, 0x22, 0x02, 0x21, 0x02, 0x11,
		0x12, 0x11, 0x12, 0x11, 0x11, 0x30, 0x11, 0x20, 0x12, 0x11, 0x12, 0x11, 0x01, 0x20, 0x01, 0x10,
		0x44, 0x23, 0x44, 0x23, 0x23, 0x22, 0x23, 0x12, 0x44, 0x23, 0x44, 0x23, 0x23, 0x22, 0x23, 0x12,
		0x23, 0x02, 0x23, 0x02, 0x22, 0x21, 0x22, 0x11, 0x23, 0x02, 0x23, 0x02, 0x12, 0x11, 0x12, 0x01,
		0x44, 0x23, 0x44, 0x23, 0x23, 0x22, 0x23, 0x12, 0x44, 0x23, 0x44, 0x23, 0x23, 0x22, 0x23, 0x12,
		0x23, 0x02, 0x23, 0x02, 0x22, 0x21, 0x22, 0x11, 0x23, 0x02, 0x23, 0x02, 0x12, 0x11, 0x12, 0x01,
		0x23, 0x12, 0x23, 0x12, 0x02, 0x11, 0x02, 0x01, 0x23, 0x12, 0x23, 0x12, 0x02, 0x11, 0x02, 0x01,
		0x22, 0x11, 0x22, 0x11, 0x21, 0x30, 0x21, 0x20, 0x22, 0x11, 0x22, 0x11, 0x11, 0x20, 0x11, 0x10,
		0x23, 0x12, 0x23, 0x12, 0x02, 0x11, 0x02, 0x01, 0x23, 0x12, 0x23, 0x12, 0x02, 0x11, 0x02, 0x01,
		0x12, 0x01, 0x12, 0x01, 0x11, 0x20, 0x11, 0x10, 0x12, 0x01, 0x12, 0x01, 0x01, 0x10, 0x01, 0x00,
	}

	association := make([]u32, len(input))
	defer delete(association)

	regions := make([dynamic]Region)
	defer delete(regions)

	stride := strings.index_byte(input, '\n') + 1
	assert(stride > 1)

	for cell, i in transmute([]u8)input {
		if cell == '\n' do continue

		cluster : bit_set[Neighbor]
		if get_cell(input, i - stride - 1) == cell do cluster += { .NW }
		if get_cell(input, i - stride    ) == cell do cluster += { .N }
		if get_cell(input, i - stride + 1) == cell do cluster += { .NE }
		if get_cell(input, i          - 1) == cell do cluster += { .W }
		if get_cell(input, i          + 1) == cell do cluster += { .E }
		if get_cell(input, i + stride - 1) == cell do cluster += { .SW }
		if get_cell(input, i + stride    ) == cell do cluster += { .S }
		if get_cell(input, i + stride + 1) == cell do cluster += { .SE }

		region := -1

		if .W in cluster {
			left_region := int(association[i-1]) - 1
			for regions[left_region].area == 0 do left_region = int(regions[left_region].perimeter)
			region = left_region
		}

		if .N in cluster {
			up_region := int(association[i-stride]) - 1
			for regions[up_region].area == 0 do up_region = int(regions[up_region].perimeter)

			if region >= 0 && region != up_region {
				root := min(region, up_region)
				leaf := max(region, up_region)

				assert(regions[root].area > 0)
				assert(regions[leaf].area > 0)
				regions[root].area += regions[leaf].area
				regions[root].perimeter += regions[leaf].perimeter
				regions[root].sides += regions[leaf].sides
				regions[leaf].area = 0
				regions[leaf].perimeter = u32(root)

				region = root
			} else {
				region = up_region
			}
		}

		if region < 0 {
			region = len(regions)
			append_nothing(&regions)
		} else {
			assert(regions[region].area != 0)
		}

		regions[region].area += 1

		score := cluster_scores[transmute(u8)cluster]
		regions[region].perimeter += u32(score & 0xf)
		regions[region].sides += u32(score >> 4)

		assert(region < int(max(u32)))
		association[i] = u32(region+1)
	}

	for region in regions {
		p1 += int(region.area) * int(region.perimeter)
		p2 += int(region.area) * int(region.sides)
	}

	return
}

DAY12_EXAMPLE ::
`RRRRIICCFF
RRRRIICCCF
VVRRRCCFFF
VVRCCCJFFF
VVVVCJJCFE
VVIVCCJJEE
VVIIICJJEE
MIIIIIJJEE
MIIISIJEEE
MMMISSJEEE`

@test
day12_example1 :: proc (t: ^testing.T) {
	p1, p2 := day12_solve(DAY12_EXAMPLE)
	testing.expect_value(t, p1, 1930)
	testing.expect_value(t, p2, 1206)
}

