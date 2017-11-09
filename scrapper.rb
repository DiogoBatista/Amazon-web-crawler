require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'open_uri_redirections'
   
url = 'https://www.amazon.com/gp/product/B01IEYHRAO'
page = Nokogiri::HTML(open(url, :allow_redirections => :safe))   
title =  page.at_css('[id="productTitle"]').text.strip 
price =  page.at_css('[id="priceblock_ourprice"]').text.strip # get only the first price

puts title 
puts price 