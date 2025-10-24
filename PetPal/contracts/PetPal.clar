;; PetPal - Digital Pet Care and Community Platform
;; A blockchain-based platform for pet profiles, care tracking,
;; and community rewards

;; Contract constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-input (err u104))

;; Token constants
(define-constant token-name "PetPal Care Token")
(define-constant token-symbol "PCT")
(define-constant token-decimals u6)
(define-constant token-max-supply u40000000000) ;; 40k tokens with 6 decimals

;; Reward amounts (in micro-tokens)
(define-constant reward-care u1500000) ;; 1.5 PCT
(define-constant reward-checkup u3000000) ;; 3 PCT
(define-constant reward-milestone u8000000) ;; 8 PCT

;; Data variables
(define-data-var total-supply uint u0)
(define-data-var next-pet-id uint u1)
(define-data-var next-care-id uint u1)

;; Token balances
(define-map token-balances principal uint)

;; Pet owner profiles
(define-map owner-profiles
  principal
  {
    username: (string-ascii 32),
    pets-owned: uint,
    care-activities: uint,
    vet-visits: uint,
    owner-level: uint, ;; 1-6
    join-date: uint
  }
)

;; Pet profiles
(define-map pet-profiles
  uint
  {
    owner: principal,
    pet-name: (string-ascii 24),
    pet-type: (string-ascii 12), ;; "dog", "cat", "bird", "fish", "reptile"
    breed: (string-ascii 24),
    age-months: uint,
    weight-grams: uint,
    registration-date: uint,
    active: bool
  }
)

;; Care activities
(define-map care-activities
  uint
  {
    pet-id: uint,
    caregiver: principal,
    activity-type: (string-ascii 16), ;; "feeding", "walking", "grooming", "playing"
    duration-minutes: uint,
    notes: (string-ascii 64),
    activity-date: uint
  }
)

;; Vet checkups
(define-map vet-checkups
  { pet-id: uint, checkup-date: uint }
  {
    owner: principal,
    checkup-type: (string-ascii 16), ;; "routine", "emergency", "vaccination"
    vet-notes: (string-ascii 128),
    next-checkup: uint,
    completed: bool
  }
)

;; Pet milestones
(define-map pet-milestones
  { owner: principal, milestone: (string-ascii 12) }
  {
    achievement-date: uint,
    pet-count: uint
  }
)

;; Helper function to get or create profile
(define-private (get-or-create-profile (owner principal))
  (match (map-get? owner-profiles owner)
    profile profile
    {
      username: "",
      pets-owned: u0,
      care-activities: u0,
      vet-visits: u0,
      owner-level: u1,
      join-date: stacks-block-height
    }
  )
)

;; Token functions
(define-read-only (get-name)
  (ok token-name)
)

(define-read-only (get-symbol)
  (ok token-symbol)
)

(define-read-only (get-decimals)
  (ok token-decimals)
)

(define-read-only (get-balance (user principal))
  (ok (default-to u0 (map-get? token-balances user)))
)

(define-private (mint-tokens (recipient principal) (amount uint))
  (let (
    (current-balance (default-to u0 (map-get? token-balances recipient)))
    (new-balance (+ current-balance amount))
    (new-total-supply (+ (var-get total-supply) amount))
  )
    (asserts! (<= new-total-supply token-max-supply) err-invalid-input)
    (map-set token-balances recipient new-balance)
    (var-set total-supply new-total-supply)
    (ok amount)
  )
)

;; Register pet
(define-public (register-pet (pet-name (string-ascii 24)) (pet-type (string-ascii 12)) (breed (string-ascii 24)) (age-months uint) (weight-grams uint))
  (let (
    (pet-id (var-get next-pet-id))
    (profile (get-or-create-profile tx-sender))
  )
    (asserts! (> (len pet-name) u0) err-invalid-input)
    (asserts! (> (len pet-type) u0) err-invalid-input)
    (asserts! (> weight-grams u0) err-invalid-input)
    
    (map-set pet-profiles pet-id {
      owner: tx-sender,
      pet-name: pet-name,
      pet-type: pet-type,
      breed: breed,
      age-months: age-months,
      weight-grams: weight-grams,
      registration-date: stacks-block-height,
      active: true
    })
    
    ;; Update owner profile
    (map-set owner-profiles tx-sender
      (merge profile {pets-owned: (+ (get pets-owned profile) u1)})
    )
    
    (var-set next-pet-id (+ pet-id u1))
    (print {action: "pet-registered", pet-id: pet-id, owner: tx-sender})
    (ok pet-id)
  )
)

;; Log care activity
(define-public (log-care-activity (pet-id uint) (activity-type (string-ascii 16)) (duration-minutes uint) (notes (string-ascii 64)))
  (let (
    (care-id (var-get next-care-id))
    (pet (unwrap! (map-get? pet-profiles pet-id) err-not-found))
    (profile (get-or-create-profile tx-sender))
  )
    (asserts! (get active pet) err-invalid-input)
    (asserts! (is-eq tx-sender (get owner pet)) err-unauthorized)
    (asserts! (> duration-minutes u0) err-invalid-input)
    
    (map-set care-activities care-id {
      pet-id: pet-id,
      caregiver: tx-sender,
      activity-type: activity-type,
      duration-minutes: duration-minutes,
      notes: notes,
      activity-date: stacks-block-height
    })
    
    ;; Update owner profile
    (map-set owner-profiles tx-sender
      (merge profile {
        care-activities: (+ (get care-activities profile) u1),
        owner-level: (+ (get owner-level profile) (/ duration-minutes u30))
      })
    )
    
    ;; Award care tokens
    (try! (mint-tokens tx-sender reward-care))
    
    (var-set next-care-id (+ care-id u1))
    (print {action: "care-activity-logged", care-id: care-id, pet-id: pet-id})
    (ok care-id)
  )
)

;; Schedule vet checkup
(define-public (schedule-vet-checkup (pet-id uint) (checkup-type (string-ascii 16)) (vet-notes (string-ascii 128)) (next-checkup-days uint))
  (let (
    (pet (unwrap! (map-get? pet-profiles pet-id) err-not-found))
    (profile (get-or-create-profile tx-sender))
    (checkup-date stacks-block-height)
  )
    (asserts! (get active pet) err-invalid-input)
    (asserts! (is-eq tx-sender (get owner pet)) err-unauthorized)
    (asserts! (> next-checkup-days u0) err-invalid-input)
    
    (map-set vet-checkups {pet-id: pet-id, checkup-date: checkup-date} {
      owner: tx-sender,
      checkup-type: checkup-type,
      vet-notes: vet-notes,
      next-checkup: (+ checkup-date next-checkup-days),
      completed: true
    })
    
    ;; Update owner profile
    (map-set owner-profiles tx-sender
      (merge profile {vet-visits: (+ (get vet-visits profile) u1)})
    )
    
    ;; Award checkup tokens
    (try! (mint-tokens tx-sender reward-checkup))
    
    (print {action: "vet-checkup-scheduled", pet-id: pet-id, owner: tx-sender})
    (ok true)
  )
)

;; Update pet info
(define-public (update-pet-weight (pet-id uint) (new-weight-grams uint))
  (let (
    (pet (unwrap! (map-get? pet-profiles pet-id) err-not-found))
  )
    (asserts! (is-eq tx-sender (get owner pet)) err-unauthorized)
    (asserts! (> new-weight-grams u0) err-invalid-input)
    
    (map-set pet-profiles pet-id (merge pet {weight-grams: new-weight-grams}))
    
    (print {action: "pet-weight-updated", pet-id: pet-id, new-weight: new-weight-grams})
    (ok true)
  )
)

;; Claim milestone
(define-public (claim-milestone (milestone (string-ascii 12)))
  (let (
    (profile (get-or-create-profile tx-sender))
  )
    (asserts! (is-none (map-get? pet-milestones {owner: tx-sender, milestone: milestone})) err-already-exists)
    
    ;; Check milestone requirements
    (let (
      (milestone-met
        (if (is-eq milestone "caregiver-20") (>= (get care-activities profile) u20)
        (if (is-eq milestone "vet-regular-10") (>= (get vet-visits profile) u10)
        (if (is-eq milestone "multi-pet-3") (>= (get pets-owned profile) u3)
        false))))
    )
      (asserts! milestone-met err-unauthorized)
      
      ;; Record milestone
      (map-set pet-milestones {owner: tx-sender, milestone: milestone} {
        achievement-date: stacks-block-height,
        pet-count: (get pets-owned profile)
      })
      
      ;; Award milestone tokens
      (try! (mint-tokens tx-sender reward-milestone))
      
      (print {action: "milestone-claimed", owner: tx-sender, milestone: milestone})
      (ok true)
    )
  )
)

;; Update username
(define-public (update-username (new-username (string-ascii 32)))
  (let (
    (profile (get-or-create-profile tx-sender))
  )
    (asserts! (> (len new-username) u0) err-invalid-input)
    (map-set owner-profiles tx-sender (merge profile {username: new-username}))
    (print {action: "username-updated", owner: tx-sender})
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-owner-profile (owner principal))
  (map-get? owner-profiles owner)
)

(define-read-only (get-pet-profile (pet-id uint))
  (map-get? pet-profiles pet-id)
)

(define-read-only (get-care-activity (care-id uint))
  (map-get? care-activities care-id)
)

(define-read-only (get-vet-checkup (pet-id uint) (checkup-date uint))
  (map-get? vet-checkups {pet-id: pet-id, checkup-date: checkup-date})
)

(define-read-only (get-milestone (owner principal) (milestone (string-ascii 12)))
  (map-get? pet-milestones {owner: owner, milestone: milestone})
)

;; Admin functions
(define-public (deactivate-pet (pet-id uint))
  (let (
    (pet (unwrap! (map-get? pet-profiles pet-id) err-not-found))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set pet-profiles pet-id (merge pet {active: false}))
    (print {action: "pet-deactivated", pet-id: pet-id})
    (ok true)
  )
)