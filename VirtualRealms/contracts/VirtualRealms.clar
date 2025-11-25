;; VirtualRealms Gaming Guild Contract
;; Description: A decentralized gaming guild treasury where players contribute loot shares and vote on prize pool distributions

;; Contract constants
(define-constant GUILD_MASTER tx-sender)
(define-constant ERR_NOT_MEMBER (err u1))
(define-constant ERR_TRIBUTE_NEEDED (err u2))
(define-constant ERR_INVALID_QUEST (err u3))
(define-constant ERR_VOTE_RECORDED (err u4))
(define-constant ERR_QUEST_ENDED (err u5))
(define-constant ERR_COOLDOWN_ERROR (err u6))
(define-constant ERR_PARAMETER_ERROR (err u7))
(define-constant ERR_REWARD_TOO_LOW (err u8))
(define-constant ERR_QUEST_UNKNOWN (err u9))

;; Manual Block Height Tracking
(define-data-var game_cycle uint u0)
(define-data-var previous_player principal tx-sender)

;; Game Cycle Progression Function
(define-public (cycle_forward)
    (begin
        ;; Prevent same player cycling twice
        (asserts! 
            (not (is-eq (var-get previous_player) tx-sender)) 
            ERR_COOLDOWN_ERROR
        )

        ;; Advance cycle
        (var-set game_cycle 
            (+ (var-get game_cycle) u1)
        )

        ;; Track player
        (var-set previous_player tx-sender)

        (ok (var-get game_cycle))
    )
)

;; Storage for guild member contributions
(define-map guild_roster 
    {member: principal} 
    {
        tribute_paid: uint,
        standing_good: bool,
        join_cycle: uint
    }
)

;; Storage for prize distribution quests
(define-map reward_quests
    {quest_id: uint}
    {
        champion_wallet: principal,
        prize_amount: uint,
        judgment_votes: uint,
        votes_approved: uint,
        prize_claimed: bool,
        quest_cycle: uint,
        voting_ends: uint
    }
)

;; Track member votes on prize quests
(define-map vote_journal
    {member: principal, quest_id: uint}
    {vote_cast: bool}
)

;; Track guild treasury and next quest ID
(define-data-var guild_treasury uint u0)
(define-data-var quest_tracker uint u1)

;; Voting period constants
(define-constant JUDGMENT_PERIOD u144) ;; Approximately 24 hours 
(define-constant MEMBER_TENURE u1440) ;; Approximately 10 days
(define-constant MAX_PRIZE_POOL u1000000000) ;; Maximum prize amount

;; Validation helper functions
(define-read-only (quest_is_registered (id uint))
    (is-some (map-get? reward_quests {quest_id: id}))
)

(define-read-only (wallet_is_valid (wallet principal))
    (and 
        (not (is-eq wallet (as-contract tx-sender)))
        (not (is-eq wallet 'SP000000000000000000002Q6VF78))
    )
)

(define-read-only (prize_is_valid (amount uint))
    (and (> amount u0) (<= amount MAX_PRIZE_POOL))
)

;; Member tribute function
(define-public (pay_guild_tribute (tribute_size uint))
    (let 
        (
            (cycle (var-get game_cycle))
        )
        (begin
            ;; Validate input
            (asserts! (prize_is_valid tribute_size) ERR_PARAMETER_ERROR)
            
            ;; Ensure minimum tribute
            (asserts! (> tribute_size u0) ERR_TRIBUTE_NEEDED)

            ;; Transfer STX to contract
            (try! (stx-transfer? tribute_size tx-sender (as-contract tx-sender)))

            ;; Register member
            (map-set guild_roster 
                {member: tx-sender} 
                {
                    tribute_paid: tribute_size,
                    standing_good: true,
                    join_cycle: cycle
                }
            )

            ;; Add to treasury
            (var-set guild_treasury 
                (+ (var-get guild_treasury) tribute_size)
            )

            (ok true)
        )
    )
)

;; Submit prize distribution quest
(define-public (initiate_reward_quest 
    (champion_wallet principal) 
    (prize_amount uint)
)
    (let 
        (
            (quest_id (var-get quest_tracker))
            (cycle (var-get game_cycle))
            (member_status 
                (unwrap! 
                    (map-get? guild_roster {member: tx-sender}) 
                    ERR_NOT_MEMBER
                )
            )
            (deadline (+ cycle JUDGMENT_PERIOD))
        )
        ;; Validate inputs
        (asserts! (wallet_is_valid champion_wallet) ERR_PARAMETER_ERROR)
        (asserts! (prize_is_valid prize_amount) ERR_REWARD_TOO_LOW)

        ;; Ensure member in good standing
        (asserts! (get standing_good member_status) ERR_NOT_MEMBER)

        ;; Ensure quest within member tenure
        (asserts! 
            (<= 
                (- cycle (get join_cycle member_status)) 
                MEMBER_TENURE
            ) 
            ERR_QUEST_ENDED
        )

        ;; Create reward quest
        (map-set reward_quests 
            {quest_id: quest_id}
            {
                champion_wallet: champion_wallet,
                prize_amount: prize_amount,
                judgment_votes: u0,
                votes_approved: u0,
                prize_claimed: false,
                quest_cycle: cycle,
                voting_ends: deadline
            }
        )

        ;; Increment quest tracker
        (var-set quest_tracker (+ quest_id u1))

        (ok quest_id)
    )
)

;; Vote on prize quest
(define-public (judge_reward_quest 
    (quest_id uint) 
    (approve_reward bool)
)
    (let 
        (
            (cycle (var-get game_cycle))
            (validated_id (asserts! (quest_is_registered quest_id) ERR_QUEST_UNKNOWN))
            (quest_details 
                (unwrap! 
                    (map-get? reward_quests {quest_id: quest_id}) 
                    ERR_INVALID_QUEST
                )
            )
            (member_status 
                (unwrap! 
                    (map-get? guild_roster {member: tx-sender}) 
                    ERR_NOT_MEMBER
                )
            )
        )

        ;; Ensure voting window is active
        (asserts! (< cycle (get voting_ends quest_details)) ERR_QUEST_ENDED)

        ;; Prevent double voting
        (asserts! 
            (not (default-to false 
                (get vote_cast (map-get? vote_journal {member: tx-sender, quest_id: quest_id}))
            )) 
            ERR_VOTE_RECORDED
        )

        ;; Update vote counts
        (map-set reward_quests 
            {quest_id: quest_id}
            (merge quest_details 
                {
                    judgment_votes: (+ (get judgment_votes quest_details) u1),
                    votes_approved: (if approve_reward 
                        (+ (get votes_approved quest_details) u1)
                        (get votes_approved quest_details)
                    )
                }
            )
        )

        ;; Record vote
        (map-set vote_journal 
            {member: tx-sender, quest_id: quest_id}
            {vote_cast: true}
        )

        (ok true)
    )
)

;; Read-only function to get current game cycle
(define-read-only (get_game_cycle)
  (var-get game_cycle)
)