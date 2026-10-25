#!/usr/bin/env ruby
# Deterministic new Selah code-native icon. Stdlib only; no SDK/build/network.
# Generates opaque PNGs into exactly this independent app's two icon paths.
require 'zlib'
require 'fileutils'

SELAH_ICON_SIZE = 1024
SELAH_ICON_GOLD = [226, 205, 145].freeze
selah_icon_source = File.expand_path('..', __dir__)
selah_icon_rows = Array.new(SELAH_ICON_SIZE) do |y|
  shade = y.to_f / (SELAH_ICON_SIZE - 1)
  color = [(45 - shade * 18).round, (32 - shade * 14).round, (59 - shade * 23).round]
  color.pack('C*') * SELAH_ICON_SIZE
end

def selah_icon_pixel(rows, x, y, rgb)
  return unless x.between?(0, SELAH_ICON_SIZE - 1) && y.between?(0, SELAH_ICON_SIZE - 1)
  rows[y][x * 3, 3] = rgb.pack('C*')
end

def selah_icon_disk(rows, center_x, center_y, radius, rgb)
  (center_y - radius - 1).floor.upto((center_y + radius + 1).ceil) do |y|
    next unless y.between?(0, SELAH_ICON_SIZE - 1)
    (center_x - radius - 1).floor.upto((center_x + radius + 1).ceil) do |x|
      next unless x.between?(0, SELAH_ICON_SIZE - 1)
      coverage = [[radius + 0.5 - Math.hypot(x - center_x, y - center_y), 0.0].max, 1.0].min
      next if coverage.zero?
      previous = rows[y][x * 3, 3].unpack('C*')
      blended = rgb.each_with_index.map { |value, i| (previous[i] + (value - previous[i]) * coverage).round }
      selah_icon_pixel(rows, x, y, blended)
    end
  end
end

# Quiet fine ring; independent source geometry, not a copied brand mark.
0.upto(3000) do |step|
  angle = step * Math::PI * 2 / 3000
  selah_icon_disk(selah_icon_rows, 512 + Math.cos(angle) * 365, 512 + Math.sin(angle) * 365, 2.0, SELAH_ICON_GOLD)
end

# A custom flowing S monogram with a small Christian cross above it.
selah_icon_curves = [
  [[635, 370], [550, 280], [363, 300], [387, 425]],
  [[387, 425], [402, 512], [640, 502], [637, 635]],
  [[637, 635], [633, 767], [450, 778], [365, 687]]
]
selah_icon_curves.each do |points|
  0.upto(220) do |step|
    t = step.to_f / 220
    u = 1 - t
    x = u**3 * points[0][0] + 3 * u**2 * t * points[1][0] + 3 * u * t**2 * points[2][0] + t**3 * points[3][0]
    y = u**3 * points[0][1] + 3 * u**2 * t * points[1][1] + 3 * u * t**2 * points[2][1] + t**3 * points[3][1]
    selah_icon_disk(selah_icon_rows, x, y, 17.0, SELAH_ICON_GOLD)
  end
end
190.upto(262) { |y| 508.upto(516) { |x| selah_icon_pixel(selah_icon_rows, x, y, SELAH_ICON_GOLD) } }
214.upto(222) { |y| 486.upto(538) { |x| selah_icon_pixel(selah_icon_rows, x, y, SELAH_ICON_GOLD) } }

def selah_icon_png_chunk(kind, contents)
  [contents.bytesize].pack('N') + kind + contents + [Zlib.crc32(kind + contents)].pack('N')
end
selah_icon_raw = selah_icon_rows.map { |row| "\x00".b + row }.join
selah_icon_png = "\x89PNG\r\n\x1a\n".b
selah_icon_png << selah_icon_png_chunk('IHDR', [SELAH_ICON_SIZE, SELAH_ICON_SIZE, 8, 2, 0, 0, 0].pack('NNC5'))
selah_icon_png << selah_icon_png_chunk('IDAT', Zlib::Deflate.deflate(selah_icon_raw, Zlib::BEST_COMPRESSION))
selah_icon_png << selah_icon_png_chunk('IEND', ''.b)
selah_icon_targets = [
  File.join(selah_icon_source, 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Selah-1024.png'),
  File.join(selah_icon_source, 'assets/icon/icon.png')
]
selah_icon_targets.each do |target|
  FileUtils.mkdir_p(File.dirname(target))
  File.binwrite(target, selah_icon_png)
  puts "Generated own opaque Selah icon: #{target}"
end
