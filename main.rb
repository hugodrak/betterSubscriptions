require 'nokogiri'
require 'open-uri'
require 'httparty'
require 'pp'
require 'json'
@baseUrl = "https://www.youtube.com"

def parse(file, type)
    if type == 1
        doc = Nokogiri::HTML(open(file))
    elsif type == 2
        response = HTTParty.get(file)
        doc = Nokogiri::HTML(response)
    end

    return doc
end

def filterUsers(doc)
    users = doc.css("a#endpoint")
    return users
end

def extractAriaInfo(aria, userName)
    p aria
    first = aria.regexp("/(?<=av #{userName}).*")
    puts first
end

def extractLength(raw)
    secs = 0
    mins = 0
    hours = 0

    secs = raw.match(/\d+?(?= minu)/).to_s.to_i
    mins = raw.match(/\d+?(?= seku)/).to_s.to_i
    hours = raw.match(/\d+?(?= timm)/).to_s.to_i

    secs = (secs + mins*60 + hours*3600)

    return secs
end

def extractAge(raw)
    secs = 0
    mins = 0
    hours = 0
    days = 0
    months = 0
    years = 0
    mins = raw.match(/\d+?(?= minu)/).to_s.to_i
    hours = raw.match(/\d+?(?= timm)/).to_s.to_i
    days = raw.match(/\d+?(?= dag)/).to_s.to_i
    months = raw.match(/\d+?(?= måna)/).to_s.to_i
    years = raw.match(/\d+?(?= år)/).to_s.to_i


    secs = (mins*60 + hours*3600 + days*86400 + months*2628288 + years*31539456)

    return secs
end

def getVideos(channel_url, count = 4)
    videos = []
    url = @baseUrl+channel_url+"/videos"
    userVideosPage = parse(url, 2)
    videosRaw = userVideosPage.css(".channels-content-item")
    videosRaw = videosRaw.take(2)

    videosRaw.each do |videoRaw|
        title = videoRaw.css(".yt-lockup-title a")[0]["title"].to_s
        href = videoRaw.css(".yt-lockup-title a")[0]["href"].to_s
        length = videoRaw.css(".yt-lockup-title .accessible-description").inner_html.to_s
        src = videoRaw.css("img")[0]["src"].to_s
        views = videoRaw.css(".yt-lockup-meta-info li")[0].inner_html.to_s.match(/\d+?(?= visningar)/).to_s
        age = extractAge(videoRaw.css(".yt-lockup-meta-info li")[1].inner_html.to_s)
        videos << {"title": title, "href": href, "length":extractLength(length), "img":src, "views": views, "age": age, "createdAt":Time.now.to_i-age}
    end
    return videos
end

def getTimeline()
    users = JSON.parse(IO.read("subscriptions.json"))
    count = JSON.parse(IO.read("config.json"))["count"]
    timeline = []
    users = users.take(2)
    p users
    users.each do |user|
        timeline << {"user": user, "videos":getVideos(user["url"], count)}
    end
    return {"timeline": timeline, "timestamp": {"text":Time.now, "UNIX": Time.now.to_i}}
end

def createHTML()
    video_hash = getTimeline()
    p video_hash["timestamp"]
    doc = Nokogiri::HTML(open("layout.html"))
    videohtml = ""
    videohtml += "<h1>Created #{video_hash['timestamp']['text']}</h3>"
    videos = video_hash['timeline']
    videos.each do |video|
        videohtml += ("<li><a><img src=\"#{video['img']}\"></a></li>")
    end
    doc.css("timeline").inner_html = videohtml
    File.open("main.html", "w+") {|file| file.write(doc.to_s)}
end

createHTML()
