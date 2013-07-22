#!/usr/bin/env ruby
#
# Name: rubycash (server)
# Auth: Gavin Lloyd <gavin@lifetime.oregonstate.edu>
# Date: Feb 2012, ECE/CS 476
# Desc: Dynamic Parameterized Partial Hash Proof-of-Work Function demo
#

require 'socket'
require 'digest/sha1'
require 'curses'
Curses::init_screen

port = 40001

digest = Digest::SHA1.new
bits = digest.size * 8
bytes = digest.size * 2 # ASCII bytes of the hex representation

static = true
req_n = 15 # minimum number of leading 0 bits required in hash
rate_limit = 40 # /sec

client_db = Hash.new # auto-maintained list of current clients
client_id = 0

# start the server
server = TCPServer.open(port)
server_count = 0 # overall count
server_time = false
server_rate = 0

# exit nicely on interrupt
trap('INT') {
  exit
}

# create curses window
cur = Curses::Window.new(0, 0, 0, 0)
cur.setpos(3,2)
cur.addstr("id\tfd\t\tValid Messages\t\tClient /sec")
cur.setpos(4,2)
cur.addstr("--\t--\t\t--------------\t\t-----------")

# wait for incoming connections
loop {
  mask_n = ((0...req_n).map{1} + (0...bits-req_n).map{0}).join.to_i(2)

  Thread.start(server.accept) { |sock|

    id = client_id
    client_id += 1

    sock_fd = sock.to_i

    # add this socket to client_db with initial values
    client_db[id] = { :id => id, :fd => sock_fd,
                      :start_time => false,
                      :count => 0, :rate => 0 }

     # rx = sock.readline
    while line = sock.gets
      break if line.length <= 2 # EOF or error, the connection is closed

      sock.puts req_n # send new n-value as ACK

      if line.length > 1

        # don't set start time until the first message is recieved
        if server_time === false
          server_time = Time.new.to_f
        end

        if client_db[id][:start_time] === false
          client_db[id][:start_time] = Time.now.to_f
        end

        # take hash and mask it
        hash_hex = digest.hexdigest line.chop
        hash_int = hash_hex.to_i(16)
        result = hash_int & mask_n

        # result of masking is 0 if the leading 0 bits are present
        if result === 0
          client_db[id][:count] += 1
          server_count += 1
        end

        # output stats
        now_time = Time.now.to_f
        total_time = now_time - client_db[id][:start_time]
        client_db[id][:rate] = (client_db[id][:count]/total_time).to_f.round(2)

        client_db.each do |k,h|
          cur.setpos(h[:id]+5, 2)
          cur.addstr("%-2s\t%-2s\t\t%-8s\t\t%-11s" %
            [h[:id].to_s, h[:fd].to_s, h[:count].to_s, h[:rate]])
        end
        cur.refresh

        # recalculate overall rate after every rate_limit*2 incoming messages
        if server_count > rate_limit*2
          now = Time.new.to_f

          server_rate = (server_count / (now - server_time)).to_f.round(2)
          server_time = now
          server_count = 0

          if !static
            # increment / decrement global client n as required
            if server_rate > rate_limit
              req_n += 1
            end

            if server_rate < rate_limit/2
              req_n -= 1
            end
          end

        end

        # display overall average rate
        cur.setpos(1,2)
        cur.addstr("[Server Overall Rate = %s/sec]\t" % server_rate)

      end
    end
    client_db.delete(id)
  }
}