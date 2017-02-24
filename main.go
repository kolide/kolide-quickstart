package main

import (
	"archive/zip"
	"bytes"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"syscall"

	"github.com/go-sql-driver/mysql"
)

func main() {
	if err := download(); err != nil {
		log.Fatal(err)
	}

	files, err := ioutil.ReadDir("bin")
	if err != nil {
		log.Fatal(err)
	}

	for _, file := range files {
		fmt.Println(file.Name())
	}

	Exec()
}

func Exec() {
	cmd, err := exec.LookPath("bin/kolide")
	if err != nil {
		log.Fatal(err)
	}

	env := os.Environ()
	fmt.Println(env)
	dsn := os.Getenv("JAWSDB_URL")
	dsn = strings.TrimPrefix(dsn, "mysql://")
	pre := strings.SplitAfter(dsn, "@")
	pre[0] = pre[0] + "tcp("
	pre[1] = strings.Replace(pre[1], "/", ")/", -1)
	dsn = strings.Join(pre, "")
	fmt.Println(dsn)
	cfg, err := mysql.ParseDSN(dsn)
	if err != nil {
		log.Fatal(err)
	}

	os.Setenv("KOLIDE_MYSQL_ADDRESS", cfg.Addr)
	os.Setenv("KOLIDE_MYSQL_PASSWORD", cfg.Passwd)
	os.Setenv("KOLIDE_MYSQL_USERNAME", cfg.User)
	os.Setenv("KOLIDE_MYSQL_DATABASE", cfg.DBName)
	os.Setenv("KOLIDE_REDIS_ADDRESS", os.Getenv("REDIS_URL"))
	os.Setenv("KOLIDE_SERVER_ADDRESS", "0.0.0.0:"+os.Getenv("PORT"))
	os.Setenv("KOLIDE_SERVER_TLS", "false")

	prepareCmd := exec.Command(cmd, "prepare", "db")
	_, err = prepareCmd.CombinedOutput()
	if err != nil {
		log.Fatal(err)
	}

	args := []string{"kolide", "serve"}
	if err := syscall.Exec(cmd, args, os.Environ()); err != nil {
		log.Fatal(err)
	}
}

func download() error {
	resp, err := http.Get("http://dl.kolide.co/bin/kolide_latest.zip")
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	b, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return err
	}

	readerAt := bytes.NewReader(b)

	zr, err := zip.NewReader(readerAt, int64(len(b)))
	if err != nil {
		return err
	}

	out, err := os.Create("bin/kolide")
	if err != nil {
		return err
	}
	defer out.Close()
	if err := out.Chmod(0755); err != nil {
		return err
	}

	for _, f := range zr.File {
		if f.Name != "linux/kolide_linux_amd64" {
			continue
		}
		src, err := f.Open()
		if err != nil {
			return err
		}
		defer src.Close()

		if _, err := io.Copy(out, src); err != nil {
			return err
		}

	}

	log.Println("downloaded kolide")
	return nil
}
