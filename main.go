package main

import (
	"archive/zip"
	"bytes"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"strings"
	"syscall"

	"github.com/go-sql-driver/mysql"
)

func main() {
	if err := download(); err != nil {
		log.Fatalf("download latest version of kolide: %s\n", err)
	}

	if err := setEnv(); err != nil {
		log.Fatalf("setting environment: %s\n", err)
	}

	if err := execBin(); err != nil {
		log.Fatalf("exec kolide binary: %s\n", err)
	}
}

func setEnv() error {
	dsn := os.Getenv("JAWSDB_URL")
	if dsn == "" {
		return errors.New("required JAWSDB_URL env variable not found")
	}

	port := os.Getenv("PORT")
	if port == "" {
		return errors.New("required env variable PORT not set")
	}

	redisURL := os.Getenv("REDIS_URL")
	if redisURL == "" {
		return errors.New("required env variable REDIS_URL not set")
	}

	rc, err := parseRedisURL(redisURL)
	if err != nil {
		return fmt.Errorf("parsing redis url %s:", err)
	}

	cfg, err := parseDSN(dsn)
	if err != nil {
		return fmt.Errorf("parsing dsn: %s", err)
	}

	jwtKey, err := randomText(24)
	if err != nil {
		return fmt.Errorf("generating jwt key: %s", err)
	}

	os.Setenv("KOLIDE_MYSQL_ADDRESS", cfg.Addr)
	os.Setenv("KOLIDE_MYSQL_PASSWORD", cfg.Passwd)
	os.Setenv("KOLIDE_MYSQL_USERNAME", cfg.User)
	os.Setenv("KOLIDE_MYSQL_DATABASE", cfg.DBName)
	os.Setenv("KOLIDE_REDIS_ADDRESS", rc.addr)
	os.Setenv("KOLIDE_REDIS_PASSWORD", rc.password)
	os.Setenv("KOLIDE_SERVER_ADDRESS", "0.0.0.0:"+port)
	os.Setenv("KOLIDE_SERVER_TLS", "false")
	os.Setenv("KOLIDE_AUTH_JWT_KEY", jwtKey)
	return nil
}

// parseDSN formats the JAWSDB_URL into mysql DSN and calls mysql.ParseDSN.
// in order for mysql.ParseDSN to correctly parse the JAWSDB_URL, the host part
// must be wrapped with `tcp()`
func parseDSN(dsn string) (*mysql.Config, error) {
	dsn = strings.TrimPrefix(dsn, "mysql://")
	pre := strings.SplitAfter(dsn, "@")
	if len(pre) < 2 {
		return nil, errors.New("unable to split mysql DSN")
	}
	pre[0] = pre[0] + "tcp("
	pre[1] = strings.Replace(pre[1], "/", ")/", -1)

	dsn = strings.Join(pre, "")
	cfg, err := mysql.ParseDSN(dsn)
	if err != nil {
		return nil, fmt.Errorf("parsing jawsdb DSN %s", err)
	}
	return cfg, nil
}

func execBin() error {
	cmd, err := exec.LookPath("bin/kolide")
	if err != nil {
		return fmt.Errorf("looking up kolide path: %s", err)
	}

	// run migrations
	prepareCmd := exec.Command(cmd, "prepare", "db", "--no-prompt")
	_, err = prepareCmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("run prepare db %s", err)
	}

	// exec kolide binary. The first arg to syscall.Exec is the
	// path of the kolide binary, and the first elemnt of args[] is
	// also the kolide binary.
	args := []string{"kolide", "serve"}
	if err := syscall.Exec(cmd, args, os.Environ()); err != nil {
		return fmt.Errorf("exec binary: %s", err)
	}

	return nil
}

type redisConn struct {
	addr     string
	password string
}

func parseRedisURL(redisURL string) (*redisConn, error) {
	ur, err := url.Parse(redisURL)
	if err != nil {
		return nil, fmt.Errorf("parsing redis URL %s", err)
	}
	password, _ := ur.User.Password()
	conn := &redisConn{
		addr:     ur.Host,
		password: password,
	}
	return conn, nil
}

func download() error {
	resp, err := http.Get("http://dl.kolide.co/bin/kolide_latest.zip")
	if err != nil {
		return fmt.Errorf("get latest kolide zip: %s", err)
	}
	defer resp.Body.Close()

	b, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("reading response body: %s", err)
	}

	readerAt := bytes.NewReader(b)
	zr, err := zip.NewReader(readerAt, int64(len(b)))
	if err != nil {
		return fmt.Errorf("create zip reader: %s", err)
	}

	// create bin/kolide file with the executable flag.
	out, err := os.OpenFile("bin/kolide", os.O_RDWR|os.O_CREATE|os.O_TRUNC, 0755)
	if err != nil {
		return fmt.Errorf("create bin/kolide file: %s", err)
	}
	defer out.Close()

	// extract the linux binary from the zip and copy it to
	// bin/kolide
	for _, f := range zr.File {
		if f.Name != "linux/kolide_linux_amd64" {
			continue
		}
		src, err := f.Open()
		if err != nil {
			return fmt.Errorf("opening zipped file: %s", err)
		}
		defer src.Close()

		if _, err := io.Copy(out, src); err != nil {
			return fmt.Errorf("copying binary from zip: %s", err)
		}
	}

	return nil
}

func randomText(keySize int) (string, error) {
	key := make([]byte, keySize)
	_, err := rand.Read(key)
	if err != nil {
		return "", err
	}

	return base64.StdEncoding.EncodeToString(key), nil
}
