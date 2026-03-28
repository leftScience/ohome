package updater

import (
	"archive/zip"
	"io"
	"os"
	"path/filepath"
	"strings"
)

func unzipArchive(src string, dest string) error {
	reader, err := zip.OpenReader(src)
	if err != nil {
		return err
	}
	defer reader.Close()
	if err := os.MkdirAll(dest, 0o755); err != nil {
		return err
	}
	for _, file := range reader.File {
		target := filepath.Join(dest, file.Name)
		if !strings.HasPrefix(filepath.Clean(target), filepath.Clean(dest)) {
			continue
		}
		if file.FileInfo().IsDir() {
			if err := os.MkdirAll(target, file.Mode()); err != nil {
				return err
			}
			continue
		}
		if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
			return err
		}
		rc, err := file.Open()
		if err != nil {
			return err
		}
		out, err := os.OpenFile(target, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, file.Mode())
		if err != nil {
			rc.Close()
			return err
		}
		if _, err := io.Copy(out, rc); err != nil {
			out.Close()
			rc.Close()
			return err
		}
		out.Close()
		rc.Close()
	}
	return nil
}
