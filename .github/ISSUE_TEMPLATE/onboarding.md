# 🎉 Welcome to the Team!

Hello @{{ github.event.inputs.github_id }}!  
This issue will guide you through your onboarding process.  
Please follow each step carefully and check off items as you complete them.

---

## 🧱 Step 1. Local Setup & Branch Creation

1. Clone the repository:

   ```bash
   git clone git@github.com:sbee-lab/infra.git
   cd <repo>
   ```

2. Create a new branch:

   ```bash
   git checkout -b onboarding/<your-username>
   ```

3. Add your user configuration:

   - Add entry to:

     - `modules/users/students.nix` _(if role = student)_
       or
       `modules/users/researchers.nix` _(if role = researchers)_
       and follow the comments

4. (Optional) Add an Age key placeholder if needed:

- If you need access for system/service secrets, add your ssh-age key on `pubkeys.json` and add your secret perimission in `.sops.nix`
- Note that you should update secrets using `inv update-sops-files`

---

## ✅ Step 2. Check and Format

- Please keep code formatting and check the flake if there's no error

```nix
nix fmt
nix flake check
```

## 💾 Step 3. Commit and Push

- Note that your commit should be signed
  see: [github docs: signing-commits](https://docs.github.com/ko/authentication/managing-commit-signature-verification/signing-commits)

```bash
git add .
git commit -m "feat: add user <your-username>"
git push origin onboarding/<your-username>
```

---

## 🔁 Step 4. Create a Pull Request

1. Go to your fork or the repository on GitHub.
2. Create a new Pull Request with:

   - **Title:** `feat: onboard <Full Name> (<username>)`
   - **Description:** Reference this issue by adding:
     `Closes #<issue-number>`

3. Request a review from your supervisor or the maintainer team. (@mulatta)

---

## 🧩 Step 5. Admin Review Checklist

_This section is for admins._

- [ ] Review user information and Nix config
- [ ] Verify SSH key
- [ ] Generate age key (if needed)
- [ ] Add age public key to `pubkeys.json`
- [ ] Update `.sops.yaml`
- [ ] Re-encrypt secrets
- [ ] Test login & access after deployment

---

✅ Once all steps are complete and your PR is merged,
we’ll close this issue automatically via `Closes #<issue-number>` in your PR.

Welcome aboard! 🚀
