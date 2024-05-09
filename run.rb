require "rmagick"
require "zip"
require "csv"

include Magick

zip_filename = ARGV[0]

if zip_filename.nil? || zip_filename == ""
  puts "Usage: bundle exec ruby run.rb \"/Users/ponny/my-file.zip\""
  exit(1)
end

work_dir = "./work_dir"
extracted_dir = File.join(work_dir, "extacted")
output_dir = File.join(work_dir, "output")
FileUtils.mkdir_p(extracted_dir)
FileUtils.mkdir_p(output_dir)

files = []
puts "Extracting files from #{zip_filename}..."
Zip::File.open(zip_filename) do |zip_file|
  zip_file.each do |entry|
    filename = entry.name.gsub(/.*\//, "")
    puts "Extracting #{filename}..."
    next if filename == ""

    files << filename

    extract_path = File.join(extracted_dir, filename)
    begin
      entry.extract(extract_path)
    rescue Zip::DestinationFileExistsError => e
      puts "Already existed."
      next
    end
  end
end

csv_file = files.select {|f| f[/\.csv$/] }.last

csv = CSV.open(File.join(extracted_dir, csv_file), headers: true)

csv.each do |row|
  name = row["Name"]
  text = row["Text"]
  handle = row["Social Handle"]
  file_name = row["File name"]

  caption = "#{text} - #{name} #{('(' + handle + ')') if handle}©"

  puts "Captioning... #{file_name} with #{caption}"

  image = Magick::ImageList.new(File.join(extracted_dir, file_name)).first

  draw = Magick::Draw.new

  caption_padding = 26
  font_size = image.rows / 30.0
  line_height = font_size + 10

  draw.pointsize = font_size
  max_text_width = image.columns - (caption_padding * 2)

  metrics = draw.get_type_metrics(image, caption)
  if metrics.width > max_text_width
    words = caption.split(' ')
    wrapped_text = ''
    line = ''
    words.each do |word|
      test_line = line + word + ' '
      test_metrics = draw.get_type_metrics(image, test_line)
      if test_metrics.width > max_text_width
        wrapped_text += line + "\n"
        line = word + ' '
      else
        line = test_line
      end
    end
    wrapped_text += line
  else
    wrapped_text = caption
  end
  rows_of_text = wrapped_text.split("\n").count

  caption_height = (rows_of_text * line_height) + (caption_padding * 2)
  rectangle_y = image.rows - caption_height

  draw.fill = '#000000'
  draw.fill_opacity(0.3)
  draw.rectangle(0, image.rows - caption_height, image.columns, image.rows)
  draw.draw(image)

  draw = Magick::Draw.new
  draw.pointsize = font_size

  current_y = rectangle_y + caption_padding + (line_height / 2) + (line_height / 3.0)  # Fudge factor
  wrapped_text.each_line do |line|
    draw.fill_opacity(1)
    draw.fill = "#ffffff"

    line_metrics = draw.get_type_metrics(image, line)
    text_x = ((image.columns - line_metrics.width) / 2) + caption_padding

    draw.annotate(image, 0, 0, text_x, current_y, line.strip)
    current_y += line_height
  end

  draw.draw(image)

  image.write(File.join(output_dir, file_name))
end
