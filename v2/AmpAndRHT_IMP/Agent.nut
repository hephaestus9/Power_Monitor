/*
Code originally from Aron Steg: http://forums.electricimp.com/discussion/comment/7904
Modified February 1st, 2014 by Nathan Seidle
Modified June 12th, 2014 by Jeramy Brian

Original license:

The MIT License (MIT)

Copyright (c) 2013 Electric Imp

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

server.log("Agent started, URL is " + http.agenturl());

//------------------------------------------------------------------------------------------------------------------------------
hex <- "";

html <- @"<HTML>
<BODY>

<form method='POST' enctype='multipart/form-data'>
Program the ATmega328 via the Imp.<br/><br/>
Step 1: Select an Intel HEX file to upload: <input type=file name=hexfile><br/>
Step 2: <input type=submit value=Send> the file to the Arduino.<br/>
Step 3: Check out your Arduino!<br/>
</form>

</BODY>
</HTML>
";


//------------------------------------------------------------------------------------------------------------------------------
// Parses a HTTP POST in multipart/form-data format
function parse_hexpost(req, res) {
    local boundary = req.headers["content-type"].slice(30);
    local bindex = req.body.find(boundary);
    local hstart = bindex + boundary.len();
    local bstart = req.body.find("\r\n\r\n", hstart) + 4;
    local fstart = req.body.find("\r\n\r\n--" + boundary + "--", bstart);
    
    /*server.log("Boundary = " + boundary);
    server.log("Headers start at = " + hstart);
    server.log("Body start at = " + bstart);
    server.log("Body finished at = " + fstart);*/

    return req.body.slice(bstart, fstart);
}


//------------------------------------------------------------------------------------------------------------------------------
// Parses a hex string and turns it into an integer
function hextoint(str) {

    if (typeof str == "integer") {
        if (str >= '0' && str <= '9') {
            return (str - '0');
        } else {
            return (str - 'A' + 10);
        }
    } else {
        switch (str.len()) {
            case 2:
                return (hextoint(str[0]) << 4) + hextoint(str[1]);
            case 4:
                return (hextoint(str[0]) << 12) + (hextoint(str[1]) << 8) + (hextoint(str[2]) << 4) + hextoint(str[3]);
        }
    }
}


//------------------------------------------------------------------------------------------------------------------------------
// Parse the hex into an array of blobs
function program(hex) {
    
    try {
        local program = [];
        local program_line = null;
        local data = blob(128);
    
        local newhex = split(hex, ": ");
        for (local l = 0; l < newhex.len(); l++) {
            local line = strip(newhex[l]);
            if (line.len() > 10) {
                local len = hextoint(line.slice(0, 2));
                local addr = hextoint(line.slice(2, 6)) / 2; // Address space is 16-bit
                local type = hextoint(line.slice(6, 8));
                if (type != 0) continue;
                for (local i = 8; i < 8+(len*2); i+=2) {
                    local datum = hextoint(line.slice(i, i+2));
                    data.writen(datum, 'b')
                }
                local checksum = hextoint(line.slice(-2));
                
                // server.log(format("%s => %04X", line.slice(2, 6), addr))
                local tell = data.tell();
                
                data.seek(0)
                if (program_line == null) {
                    program_line = {};
                    program_line.len <- tell;
                    program_line.addr <- addr;
                    program_line.data <- data.readblob(tell);
                } else {
                    program_line.len = tell;
                    program_line.data = data.readblob(tell);
                }
                
                if (tell == data.len()) {
                    program.push(program_line);
                    program_line = null;
                    data.seek(0);
                }
            }
        }
        
        // Add whatever is left
        if (program_line != null) {
            program.push(program_line);
            program_line = null;
            data.seek(0);
        }
        
        device.send("burn", program)
        
    } catch (e) {
        server.log(e)
        return "";
    }
    
}


//********************BEGIN XIVELY********************
//Code written by @beardedinventor modified for use by Joel Wehr
API_Key <- "OCEePcRk66XBGPXWBn918aTIqJH8JOL6muhg2gybPzZOWcXV";          //Type your Xively API Key
Feed_ID <- "876819383"           //Type your Feed ID
Channel_ID4 <- "combined";    //Type your Channel ID
Channel_ID3 <- "main1";    //Type your Channel ID
Channel_ID2 <- "main2";
Channel_ID1 <- "humidity1";
Channel_ID0 <- "temp1";

Xively <- {};    // this makes a 'namespace'
class Xively.Client {
    ApiKey = null;
    triggers = [];

        constructor(apiKey) {
                this.ApiKey = apiKey;
        }
        
        /*****************************************
         * method: PUT
         * IN:
         *   feed: a XivelyFeed we are pushing to
         *   ApiKey: Your Xively API Key
         * OUT:
         *   HttpResponse object from Xively
         *   200 and no body is success
         *****************************************/
        function Put(feed){
                local url = "https://api.xively.com/v2/feeds/" + feed.FeedID + ".json";
                local headers = { "X-ApiKey" : ApiKey, "Content-Type":"application/json", "User-Agent" : "Xively-Imp-Lib/1.0" };
                local request = http.put(url, headers, feed.ToJson());

                return request.sendsync();
        }
        
        /*****************************************
         * method: GET
         * IN:
         *   feed: a XivelyFeed we fulling from
         *   ApiKey: Your Xively API Key
         * OUT:
         *   An updated XivelyFeed object on success
         *   null on failure
         *****************************************/
        function Get(feed){
                local url = "https://api.xively.com/v2/feeds/" + feed.FeedID + ".json";
                local headers = { "X-ApiKey" : ApiKey, "User-Agent" : "xively-Imp-Lib/1.0" };
                local request = http.get(url, headers);
                local response = request.sendsync();
                if(response.statuscode != 200) {
                        server.log("error sending message: " + response.body);
                        return null;
                }
        
                local channel = http.jsondecode(response.body);
                for (local i = 0; i < channel.datastreams.len(); i++)
                {
                        for (local j = 0; j < feed.Channels.len(); j++)
                        {
                                if (channel.datastreams[i].id == feed.Channels[j].id)
                                {
                                        feed.Channels[j].current_value = channel.datastreams[i].current_value;
                                        break;
                                }
                        }
                }
        
                return feed;
        }

}
    

class Xively.Feed{
    FeedID = null;
    Channels = null;
    
    constructor(feedID, channels)
    {
        this.FeedID = feedID;
        this.Channels = channels;
    }
    
    function GetFeedID() { return FeedID; }

    function ToJson()
    {
        local json = "{ \"datastreams\": [";
        for (local i = 0; i < this.Channels.len(); i++)
        {
            json += this.Channels[i].ToJson();
            if (i < this.Channels.len() - 1) json += ",";
        }
        json += "] }";
        return json;
    }
}

class Xively.Channel {
    id = null;
    current_value = null;
    
    constructor(_id)
    {
        this.id = _id;
    }
    
    function Set(value) { 
            this.current_value = value; 
    }
    
    function Get() { 
            return this.current_value; 
    }
    
    function ToJson() { 
            local json = http.jsonencode({id = this.id, current_value = this.current_value });
        server.log(json);
        return json;
    }
}

client <- Xively.Client(API_Key);

//********************END XIVELY********************


//------------------------------------------------------------------------------------------------------------------------------
// Handle the agent requests
http.onrequest(function (req, res) {
    // server.log(req.method + " to " + req.path)
    if (req.method == "GET") {
        res.send(200, html);
    } else if (req.method == "POST") {
        if ("content-type" in req.headers) {
            if (req.headers["content-type"].slice(0, 19) == "multipart/form-data") {
                hex = parse_hexpost(req, res);
                if (hex == "") {
                    res.header("Location", http.agenturl());
                    res.send(302, "HEX file uploaded");
                } else {
                    device.on("done", function(ready) {
                        res.header("Location", http.agenturl());
                        res.send(302, "HEX file uploaded");                        
                        server.log("Programming completed")
                        hex = "";
                    })
                    server.log("Programming started")
                    program(hex);
                }
            }
        }
    }
})


//------------------------------------------------------------------------------------------------------------------------------
// Handle the device coming online
device.on("ready", function(ready) {
    if (ready && hex != "") {
        program(hex);
    }
});


device.on("Status", function(v) {
    if(v.len()>0){
        Channel0 <- Xively.Channel(Channel_ID0);
        Channel1 <- Xively.Channel(Channel_ID1);
        Channel2 <- Xively.Channel(Channel_ID2);
        Channel3 <- Xively.Channel(Channel_ID3);
        Channel4 <- Xively.Channel(Channel_ID4);
        Channel0.Set(v[0].tofloat());
        Channel1.Set(v[1].tofloat());
        Channel2.Set(v[2].tofloat());
        Channel3.Set(v[3].tofloat());
        Channel4.Set(v[4].tofloat());
        feed1 <- Xively.Feed(Feed_ID, [Channel0, Channel1, Channel2, Channel3, Channel4]);
        client.Put(feed1);
    }
});

//------------------------------------------------------------------------------------------------------------------------------
// Handle the device finishing
device.on("done", function(done) {
    if (done) {
        hex = "";
    }
});

