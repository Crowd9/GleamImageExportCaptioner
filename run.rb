# frozen_string_literal: true

require "rmagick"
require "zip"
require "csv"

CAPTION_PADDING = 26

def text_draw(font_size)
  draw = Magick::Draw.new
  draw.pointsize = font_size
  draw
end

def wrap_text(draw, image, text, max_width)
  return text if draw.get_type_metrics(image, text).width <= max_width

  text.split.each_with_object([""]) do |word, lines|
    test_line = "#{lines.last}#{word} "
    if draw.get_type_metrics(image, test_line).width > max_width
      lines << "#{word} "
    else
      lines[-1] = test_line
    end
  end.join("\n")
end

def draw_background(image, height)
  draw = Magick::Draw.new
  draw.fill = "#000000"
  draw.fill_opacity(0.3)
  draw.rectangle(0, image.rows - height, image.columns, image.rows)
  draw.draw(image)
end

def draw_lines(image, text, font_size, line_height, first_line_y)
  draw = text_draw(font_size)
  current_y = first_line_y
  text.each_line do |line|
    draw.fill_opacity(1)
    draw.fill = "#ffffff"

    text_x = ((image.columns - draw.get_type_metrics(image, line).width) / 2) + CAPTION_PADDING
    draw.annotate(image, 0, 0, text_x, current_y, line.strip)
    current_y += line_height
  end
  draw.draw(image)
end

zip_filename = ARGV[0]

if zip_filename.nil? || zip_filename == ""
  puts "Usage: bundle exec ruby run.rb \"/Users/ponny/my-file.zip\""
  exit(1)
end

work_dir = File.join("./work_dir", zip_filename)
extracted_dir = File.join(work_dir, "extacted")
output_dir = File.join(work_dir, "output")
FileUtils.mkdir_p(extracted_dir)
FileUtils.mkdir_p(output_dir)

files = []
puts "Extracting files from #{zip_filename}..."
Zip::File.open(zip_filename) do |zip_file|
  zip_file.each do |entry|
    filename = entry.name.gsub(%r{.*/}, "")
    puts "Extracting #{filename}..."
    next if filename == ""

    files << filename

    extract_path = File.join(extracted_dir, filename)
    begin
      entry.extract(extract_path)
    rescue Zip::DestinationFileExistsError
      puts "Already existed."
      next
    end
  end
end

csv_file = files.select { |f| f[/\.csv$/] }.last

csv = CSV.open(File.join(extracted_dir, csv_file), headers: true)

csv.each do |row|
  name = row["Name"]
  text = row["Text"]
  handle = row["Social Handle"]
  file_name = row["File name"]

  caption = "#{text} - #{name} #{"(#{handle})" if handle}©"

  puts "Captioning... #{file_name} with #{caption}"

  image = Magick::ImageList.new(File.join(extracted_dir, file_name)).first

  font_size = image.rows / 30.0
  line_height = font_size + 10
  max_text_width = image.columns - (CAPTION_PADDING * 2)

  wrapped_text = wrap_text(text_draw(font_size), image, caption, max_text_width)
  rows_of_text = wrapped_text.split("\n").count
  caption_height = (rows_of_text * line_height) + (CAPTION_PADDING * 2)

  rectangle_y = image.rows - caption_height
  first_line_y = rectangle_y + CAPTION_PADDING + (line_height / 2) + (line_height / 4) # Fudge factor

  draw_background(image, caption_height)
  draw_lines(image, wrapped_text, font_size, line_height, first_line_y)

  image.write(File.join(output_dir, file_name))
end
