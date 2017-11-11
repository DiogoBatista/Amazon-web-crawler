require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'open_uri_redirections'
   
url = 'https://www.amazon.com/gp/product/B01IEYHRAO'
#url = 'https://www.amazon.de/gp/product/B01K3ML98Q/ref=s9_acsd_al_bw_hr_ABROTONE_2_ot_w?pf_rd_m=A3JWKAKR8XB7XF&pf_rd_s=merchandised-search-3&pf_rd_r=HTKMS30K95YT62XFG50Y&pf_rd_r=HTKMS30K95YT62XFG50Y&pf_rd_t=101&pf_rd_p=3d1bf002-e735-4654-a69c-24a925f0ee75&pf_rd_p=3d1bf002-e735-4654-a69c-24a925f0ee75&pf_rd_i=1624983031'
#url = 'https://www.amazon.co.uk/gp/product/B01DFKBL68/ref=s9u_simh_gw_i2?ie=UTF8&fpl=fresh&pd_rd_i=B01DFKBL68&pd_rd_r=5606e960-c6d0-11e7-97d5-4d22ac17510d&pd_rd_w=ak8kF&pd_rd_wg=FemdA&pf_rd_m=A3P5ROKL5A1OLE&pf_rd_s=&pf_rd_r=B7C96V1VVCDT2BD2YFPH&pf_rd_t=36701&pf_rd_p=187bec3b-0822-4044-bbe9-441718232b3f&pf_rd_i=desktop'



page = Nokogiri::HTML(open(url, :allow_redirections => :safe))   
#todo add 503 response handler

title =  page.at_css('[id="productTitle"]').text.strip 
price =  page.at_css('[id="priceblock_ourprice"]').text.strip.split('-')[0]
rating = page.at_css('[id="averageCustomerReviews"]').css('i.a-icon-star').css("span.a-icon-alt").text


if price.include? "EUR "
   currency = '€'
elsif price.include? "$"
   	currency = '$'
   else price.include? "£"
   	currency = '£'
end

price = price.gsub(/[$£EUR ]/, '')
puts title
puts price
puts currency
puts rating