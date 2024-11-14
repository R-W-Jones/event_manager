require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def clean_phone_number(phone_number)
  phone_number = phone_number.to_s.gsub(/\D/, '') # Remove non-digit characters
  if phone_number.length == 10
    phone_number # Valid 10-digit number
  elsif phone_number.length == 11 && phone_number[0] == '1'
    phone_number[1..-1] # Remove the leading 1
  else
    nil # Invalid number
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
   []
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')
  filename = "output/thanks_#{id}.html"
  File.open(filename, 'w') { |file| file.puts form_letter }
end

def registration_hour(registration_datetime)
  DateTime.strptime(registration_datetime, '%m/%d/%Y %H:%M').hour
end

def registration_day_of_week(registration_datetime)
  DateTime.strptime(registration_datetime, '%m/%d/%Y %H:%M').wday
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('lib/form_letter.erb')
erb_template = ERB.new template_letter

hourly_counts = Hash.new(0)
day_of_week_counts = Hash.new(0)

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone = clean_phone_number(row[:homephone])
  legislators = legislators_by_zipcode(zipcode)
  registration_time = row[:regdate]
  
  hour = registration_hour(registration_time)
  day_of_week = registration_day_of_week(registration_time)
  
  hourly_counts[hour] += 1
  day_of_week_counts[day_of_week] += 1

  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)
end

# Output hourly counts
puts "Registrations by Hour:"
hourly_counts.each do |hour, count|
  puts "Hour #{hour}: #{count} registrations"
end

# Output day of the week counts
puts "Registrations by Day of the Week:"
days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
day_of_week_counts.each do |day, count|
  puts "#{days[day]}: #{count} registrations"
end

