package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

func log(msg string)  { fmt.Printf("[%s] %s\n", time.Now().Format("15:04:05"), msg) }
func ok(msg string)   { fmt.Printf("  [OK]   %s\n", msg) }
func fail(msg string) { fmt.Printf("  [FAIL] %s\n", msg) }

var (
	dryRun   bool
	repoRoot string
)

func run(name string, args ...string) error {
	if dryRun {
		fmt.Printf("  [dry-run] %s %s\n", name, strings.Join(args, " "))
		return nil
	}
	cmd := exec.Command(name, args...)
	cmd.Dir = repoRoot
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func must(err error, msg string) {
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: %s: %v\n", msg, err)
		os.Exit(1)
	}
}

func capture(name string, args ...string) string {
	cmd := exec.Command(name, args...)
	cmd.Dir = repoRoot
	out, _ := cmd.Output()
	return string(out)
}

// findRepoRoot walks up from dir until it finds Gaku.sln.
func findRepoRoot(dir string) (string, error) {
	for {
		if _, err := os.Stat(filepath.Join(dir, "Gaku.sln")); err == nil {
			return dir, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return "", fmt.Errorf("Gaku.sln not found — run from inside the repo")
		}
		dir = parent
	}
}

func main() {
	flag.BoolVar(&dryRun, "dry-run", false, "Print commands without executing them")
	flag.Parse()

	const image      = "gaku-web"
	const namespace  = "gaku"
	const deployment = "gaku-web"

	cwd, err := os.Getwd()
	must(err, "get working directory")
	repoRoot, err = findRepoRoot(cwd)
	must(err, "find repo root")
	must(os.Chdir(repoRoot), "chdir to repo root")

	log("Step 1: Exporting OCI build args (GIT_COMMIT, BUILD_TIMESTAMP)")
	gitCommit := strings.TrimSpace(capture("git", "rev-parse", "HEAD"))
	buildTimestamp := time.Now().UTC().Format("2006-01-02T15:04:05Z")
	log(fmt.Sprintf("  GIT_COMMIT=%s  BUILD_TIMESTAMP=%s", gitCommit[:12], buildTimestamp))

	log(fmt.Sprintf("Step 2: Building Docker image '%s:latest' (Gaku.Web + Infrastructure + Application + Domain)", image))
	must(run("docker", "build",
		"-f", "docker/Dockerfile.Gaku.Web",
		"--build-arg", "GIT_COMMIT="+gitCommit,
		"--build-arg", "BUILD_TIMESTAMP="+buildTimestamp,
		"-t", image+":latest",
		"."), "docker build")

	log("Step 3: Loading image into minikube")
	must(run("minikube", "image", "load", image+":latest"), "minikube image load")

	log(fmt.Sprintf("Step 4: Restarting deployment '%s' in namespace '%s'", deployment, namespace))
	must(run("kubectl", "rollout", "restart", "deployment/"+deployment, "-n", namespace), "kubectl rollout restart")

	log("Step 5: Waiting for rollout to complete (timeout 90s)")
	must(run("kubectl", "rollout", "status", "deployment/"+deployment, "-n", namespace, "--timeout=90s"), "kubectl rollout status")

	fmt.Println("\n=== Result ===")

	if dryRun {
		ok("Dry-run complete — no actual changes made")
	} else {
		images := capture("docker", "images", "--format", "{{.Repository}}:{{.Tag}}")
		if strings.Contains(images, image+":latest") {
			ok(fmt.Sprintf("Docker image '%s:latest' exists locally", image))
		} else {
			fail(fmt.Sprintf("Docker image '%s:latest' not found locally", image))
		}

		minikubeImages := capture("minikube", "image", "ls")
		if strings.Contains(minikubeImages, image) {
			ok(fmt.Sprintf("Image '%s' present in minikube", image))
		} else {
			fail(fmt.Sprintf("Image '%s' not found in minikube image list", image))
		}

		pods := capture("kubectl", "get", "pod", "-n", namespace, "-l", "app="+deployment, "--no-headers")
		if strings.Contains(pods, "1/1") && strings.Contains(pods, "Running") {
			ok(fmt.Sprintf("Deployment '%s': Running 1/1", deployment))
		} else {
			fail(fmt.Sprintf("Deployment '%s': not Running 1/1 (current: %s)", deployment, strings.TrimSpace(pods)))
		}
	}

	fmt.Println()
	log("Done.")
}
