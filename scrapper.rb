require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'open_uri_redirections'
   
page = Nokogiri::HTML(open('http://github.com', :allow_redirections => :safe))   
puts page   # => Nokogiri::HTML::Document
