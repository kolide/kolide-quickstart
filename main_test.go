package main

import "testing"

func TestParseRedisURL(t *testing.T) {
	redisURL := "redis://h:asdfqwer1234asdf@ec2-111-1-1-1.compute-1.amazonaws.com:111"
	conn, err := parseRedisURL(redisURL)
	if err != nil {
		t.Fatal(err)
	}
	if have, want := conn.password, "asdfqwer1234asdf"; have != want {
		t.Errorf("have %v, want %v", have, want)
	}
	if have, want := conn.addr, "ec2-111-1-1-1.compute-1.amazonaws.com:111"; have != want {
		t.Errorf("have %v, want %v", have, want)
	}
}
