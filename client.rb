#!/usr/bin/env ruby
#
# Name: rubycash (client)
# Auth: Gavin Lloyd <gavin@lifetime.oregonstate.edu>
# Date: Feb 2012, ECE/CS 476
# Desc: Dynamic Parameterized Partial Hash Proof-of-Work Function demo
#

require 'socket'
require 'digest/sha1'
require 'curses'
Curses::init_screen

host = 'localhost'
port = 40001

digest = Digest::SHA1.new
bits = digest.size * 8
bytes = digest.size * 2 # ASCII bytes of the hex representation

req_n = 11 # minimum number of leading 0 bits required in hash
           # this gets reset after the first ACK to the server preference!

sigint = false
count = 0
line_no = 2
line_max = 15
line_init = line_no + 1

# open a connection to the server
sock = TCPSocket.open(host, port)

# keep track of stats
start_time = Time.now.to_f

# close socket and exit after interrupt
trap('INT') { sigint = true }

# create curses window
cur = Curses::Window.new(0, 0, 0, 0)

# always try to send messages at the maximum rate
loop {

  # recalculate bitmask
  mask_n = ((0...req_n).map{1} + (0...bits-req_n).map{0}).join.to_i(2)

  # save current time
  time = Time.now.to_i

  # generate random email address
  email  = (0..3).map{('a'..'z').to_a[rand(26)]}.join # username
  email += '@'
  email += (0..7).map{('a'..'z').to_a[rand(26)]}.join # domain
  email += '.com'

  # pick an initial nonce value
  nonce = -1 # rand(2**16)

  line_no = (line_no + 1) % line_max
  if line_no === 0 or line_no === line_init
    line_no = line_init

    cur.setpos(1,1)
    cur.addstr("%-*s   Header" % [bytes, "Valid Header Hash"])
    cur.setpos(2,1)
    cur.addstr("%-*s   ------" % [bytes, (0...bytes).map{'-'}.join])
  end

  begin

    nonce += 1 # increment nonce to change the resulting hash

    # form header as => time:email:nonce
    headers = Array.new
    headers.push(time)
    headers.push(email)
    headers.push(nonce)

    # take hash and mask it
    header = headers.join(':')
    hash_hex = digest.hexdigest header
    hash_int = hash_hex.to_i(16)

    result = hash_int & mask_n

  end while result != 0 # masked hash will be 0 when hash is valid

  cur.setpos(line_no,1)
  cur.addstr("%s   %s    " % [hash_hex, header])
  cur.refresh

  # interrupt was called, close and exit now
  if sigint
    sock.puts 0
    sock.close
    exit
  end

  # send to server
  sock.puts header
  count += 1

  # get new n-value back from server
  if ack = sock.recv(1024)
    req_n = ack.to_i
    cur.setpos(1,19)
    cur.setpos(line_max+2,1)
    cur.addstr("[n = #{req_n}]\t")
  end
}