#!/usr/bin/env python3
"""Insert LCKFB 3.1-inch ST7701 panel into panel-sitronix-st7701.c"""
import sys

path = sys.argv[1]
with open(path) as f:
    c = f.read()

new_panel = '''
static void lckfb_31inch_gip_sequence(struct st7701 *st7701)
{
	ST7701_WRITE(st7701, 0xEE, 0x42);
	ST7701_WRITE(st7701, 0xE0, 0x00, 0x00, 0x02);
	ST7701_WRITE(st7701, 0xE1,
		    0x04, 0xA0, 0x06, 0xA0,
		    0x05, 0xA0, 0x07, 0xA0,
		    0x00, 0x44, 0x44);
	ST7701_WRITE(st7701, 0xE2,
		    0x00, 0x00, 0x33, 0x33,
		    0x01, 0xA0, 0x00, 0x00,
		    0x01, 0xA0, 0x00, 0x00);
	ST7701_WRITE(st7701, 0xE3, 0x00, 0x00, 0x33, 0x33);
	ST7701_WRITE(st7701, 0xE4, 0x44, 0x44);
	ST7701_WRITE(st7701, 0xE5,
		    0x0C, 0x30, 0xA0, 0xA0,
		    0x0E, 0x32, 0xA0, 0xA0,
		    0x08, 0x2C, 0xA0, 0xA0,
		    0x0A, 0x2E, 0xA0, 0xA0);
	ST7701_WRITE(st7701, 0xE6, 0x00, 0x00, 0x33, 0x33);
	ST7701_WRITE(st7701, 0xE7, 0x44, 0x44);
	ST7701_WRITE(st7701, 0xE8,
		    0x0D, 0x31, 0xA0, 0xA0,
		    0x0F, 0x33, 0xA0, 0xA0,
		    0x09, 0x2D, 0xA0, 0xA0,
		    0x0B, 0x2F, 0xA0, 0xA0);
	ST7701_WRITE(st7701, 0xEB,
		    0x00, 0x01, 0xE4, 0xE4,
		    0x44, 0x88, 0x00);
	ST7701_WRITE(st7701, 0xED,
		    0xFF, 0xF5, 0x47, 0x6F,
		    0x0B, 0xA1, 0xA2, 0xBF,
		    0xFB, 0x2A, 0x1A, 0xB0,
		    0xF6, 0x74, 0x5F, 0xFF);
	ST7701_WRITE(st7701, 0xEF,
		    0x08, 0x08, 0x08, 0x40,
		    0x3F, 0x64);
}

static const struct drm_display_mode lckfb_31inch_mode = {
	.clock		= 18480,

	.hdisplay	= 800,
	.hsync_start	= 800 + 10,
	.hsync_end	= 800 + 10 + 10,
	.htotal		= 800 + 10 + 10 + 20,

	.vdisplay	= 480,
	.vsync_start	= 480 + 16,
	.vsync_end	= 480 + 16 + 2,
	.vtotal		= 480 + 16 + 2 + 2,

	.width_mm	= 68,
	.height_mm	= 41,

	.flags		= DRM_MODE_FLAG_NHSYNC | DRM_MODE_FLAG_NVSYNC,

	.type		= DRM_MODE_TYPE_DRIVER | DRM_MODE_TYPE_PREFERRED,
};

static const struct st7701_panel_desc lckfb_31inch_desc = {
	.mode		= &lckfb_31inch_mode,
	.lanes		= 2,
	.format		= MIPI_DSI_FMT_RGB888,
	.panel_sleep_delay = 80,

	.gip_sequence	= lckfb_31inch_gip_sequence,
};

'''

anchor = "static const struct of_device_id st7701_dsi_of_match[]"
assert anchor in c, "anchor not found"
c = c.replace(anchor, new_panel + "\n" + anchor)

old_match = '\t{ .compatible = "anbernic,rg-arc-panel", .data = &rg_arc_desc },'
new_match = '\t{ .compatible = "anbernic,rg-arc-panel", .data = &rg_arc_desc },\n\t{ .compatible = "lckfb,3.1-inch-st7701", .data = &lckfb_31inch_desc },'
assert old_match in c, "match anchor not found"
c = c.replace(old_match, new_match)

with open(path, "w") as f:
    f.write(c)
print("patched OK")
