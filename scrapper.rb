require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'open_uri_redirections'
require 'byebug'
require 'net/http'
require 'json'

def trimUrl(url)
	if url.to_s.include? "/ref="
		url = url.gsub(/\/ref=.*/, '')
	end

	url
end

def getImgUrlIfBase24(imgUrl, page)
	if imgUrl.include? "data:image/jpeg;base64"
		imgUrl = page.at_css('[id="imgTagWrapperId"]').css('img').attr('data-old-hires').to_s
	end
	imgUrl
end

def removeCurrencyFromPrice(price)
	price = price.gsub(/[$£EUR ]/, '')
end

def changeImgUrlToFormat(imgUrl, format)
	imgUrl = imgUrl.gsub(/\.\_S\w[0-9]+\_/, format)
end

def getCurrencyFromPrice(price)
	if price.include? "EUR "
		currency = '€'
	elsif price.include? "$"
		currency = '$'
	else price.include? "£"
		currency = '£'
	end
end

def sendProductToApi(apiHost, params, authorization)
	apiUrl = URI.parse(apiHost + '/api/products')
	req = Net::HTTP::Post.new(apiUrl, {
		'Content-Type' => 'application/json',
		'Authorization' => authorization
		})
	req.body = params.to_json
	res = Net::HTTP.start(apiUrl.hostname, apiUrl.port).request(req)
	print res.inspect
end

# url = 'https://www.amazon.com/gp/product/B01IEYHRAO'
#url = 'https://www.amazon.de/gp/product/B01K3ML98Q/ref=s9_acsd_al_bw_hr_ABROTONE_2_ot_w?pf_rd_m=A3JWKAKR8XB7XF&pf_rd_s=merchandised-search-3&pf_rd_r=HTKMS30K95YT62XFG50Y&pf_rd_r=HTKMS30K95YT62XFG50Y&pf_rd_t=101&pf_rd_p=3d1bf002-e735-4654-a69c-24a925f0ee75&pf_rd_p=3d1bf002-e735-4654-a69c-24a925f0ee75&pf_rd_i=1624983031'#
url = 'https://www.amazon.co.uk/gp/product/B01DFKBL68'
apiUrl = 'http://localhost:8001'

url = trimUrl(url)

authorization = '907442acc38d3235871954406b3eee3d3cd6d215'
page = Nokogiri::HTML(open(url, allow_redirections: :safe, "User-Agent" => "", "From" => "foo@bar.invalid", "Referer" => "http://www.ruby-lang.org/"))# todo add 503 response handler

name = page.at_css('[id="productTitle"]').text.strip
price = page.at_css('[id="priceblock_ourprice"]').text.strip.split('-')[0]
rating = page.at_css('[id="averageCustomerReviews"]').css('i.a-icon-star').css("span.a-icon-alt").text

imgPageElement = page.at_css('[id="imgTagWrapperId"]').css('img').attr('src')
imgUrl = getImgUrlIfBase24(imgPageElement.to_s, page)

currency = getCurrencyFromPrice(price)
price = removeCurrencyFromPrice(price)

imgUrl = changeImgUrlToFormat(imgUrl, '_SL400_')

params = {
	'name' => name,
	'photo' => imgUrl,
	'price' => price,
	'currency' => currency,
	'rating' => rating,
	'url' => url
}

sendProductToApi(apiUrl, params, authorization)