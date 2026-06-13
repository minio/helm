// MinIO, Inc. CONFIDENTIAL
//
// [2014] - [2026] MinIO, Inc. All Rights Reserved.
//
// NOTICE:  All information contained herein is, and remains the property
// of MinIO, Inc and its suppliers, if any.  The intellectual and technical
// concepts contained herein are proprietary to MinIO, Inc and its suppliers
// and may be covered by U.S. and Foreign Patents, patents in process, and are
// protected by trade secret or copyright law. Dissemination of this information
// or reproduction of this material is strictly forbidden unless prior written
// permission is obtained from MinIO, Inc.

package directpv

import (
	"embed"
	"io"
	"path"
	"strings"

	"sigs.k8s.io/kustomize/kyaml/filesys"
)

//go:embed base/* common/* legacy/* openshift/* openshift-with-legacy/*
var embeddedFS embed.FS

// EmbeddedFS returns embedded kustomization assets
func EmbeddedFS() embed.FS {
	return embeddedFS
}

func copyFile(memFS filesys.FileSystem, embeddedFS embed.FS, sourceFilename, destFilename string) error {
	sourceFile, err := embeddedFS.Open(sourceFilename)
	if err != nil {
		return err
	}
	defer sourceFile.Close()

	statInfo, err := sourceFile.Stat()
	if err != nil {
		return err
	}

	destFile, err := memFS.Create(destFilename)
	if err != nil {
		return err
	}
	defer destFile.Close()

	_, err = io.CopyN(destFile, sourceFile, statInfo.Size())
	return err
}

func copyDir(memFS filesys.FileSystem, embeddedFS embed.FS, sourceDir, destDir string) error {
	if err := memFS.MkdirAll(destDir); err != nil {
		return err
	}

	entries, err := embeddedFS.ReadDir(sourceDir)
	if err != nil {
		return err
	}

	for _, entry := range entries {
		source := path.Join(sourceDir, entry.Name())
		dest := path.Join(destDir, entry.Name())

		switch {
		case entry.IsDir():
			err = copyDir(memFS, embeddedFS, source, dest)
		case !strings.HasSuffix(source, ".go"): // skip Go source file
			err = copyFile(memFS, embeddedFS, source, dest)
		}

		if err != nil {
			return err
		}
	}

	return nil
}

// Copy copies embed FS into prefix in memory FS
func Copy(memFS filesys.FileSystem, embeddedFS embed.FS, prefix string) error {
	return copyDir(memFS, embeddedFS, ".", prefix+"/")
}
