#!/bin/bash
cd /opt/stacks || exit

if [[ -n $(git status -s) ]]; then
  echo "Committing changes..."
  git add .
  git commit -m "Auto-backup: $(date +'%Y-%m-%d %H:%M')"
fi

if [[ $(git log origin/main..HEAD --oneline | wc -l) -gt 0 ]]; then
  echo "Pushing to GitHub..."
  git push origin main
  echo "✅ Done."
else
  echo "Nothing to push."
fi
