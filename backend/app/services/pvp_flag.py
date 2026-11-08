"""The Event Pack: one authoritative flag, two evidence trails, one final capture."""
from dataclasses import dataclass
from random import Random

MODE = "event_flag_v1"
DURATION_MS = 120_000
FILES = ("poster.svg", "preview.apk")
RECORDS = ("banner.chat", "poster.chat")


@dataclass
class Trail:
    step: int = 0
    inspected: bool = False
    revision: int = 0
    feedback: str = ""


@dataclass
class FlagRace:
    attacker: str
    trails: dict[str, Trail]
    relay: str
    gateway: str
    delivery: str
    original: str
    ends_at: int

    @classmethod
    def start(cls, host: str, guest: str, preferences: dict[str, str], rng: Random, starts_at: int) -> "FlagRace":
        preferred = preferences.get(host)
        if preferred == preferences.get(guest):
            attacker = rng.choice((host, guest))
        else:
            attacker = host if preferred == "attacker" else guest
        return cls(attacker, {host: Trail(), guest: Trail()}, rng.choice(("relay-a", "relay-b")),
                   rng.choice(("desk-a", "desk-b")), f"DL-{rng.randrange(100, 999)}",
                   rng.choice(RECORDS), starts_at + DURATION_MS)

    def station(self, user: str) -> tuple[str, str, str, str, dict[str, str], str]:
        step = self.trails[user].step
        attacking = user == self.attacker
        if step == 0 and attacking:
            return ("INVITATION", "Expand destination", "Club poster pack • View event artwork",
                    f"Displayed: design.school.example\nExpanded: {self.relay}.example/event-pack\nTrace the delivery to the host in the expanded address.",
                    {"relay-a": "RELAY-A", "relay-b": "RELAY-B"}, self.relay)
        if step == 0:
            return ("INVITATION", "Compare directory", "Club poster pack • From: Student Design Desk",
                    f"Message: Design Desk <event@design-help.example>\nPinned school directory: report suspicious deliveries to {self.gateway.upper()}. Route the incident through that verified desk.",
                    {"desk-a": "DESK-A", "desk-b": "DESK-B"}, self.gateway)
        if step == 1 and attacking:
            return ("RELAY MANIFEST", "Read manifest", f"Intercepted event pack • {self.delivery}",
                    f"Delivery {self.delivery} requested installation. Inspect the file listing and mark the package for that delivery.",
                    {FILES[0]: f"{FILES[0]} / PRINT", FILES[1]: f"{FILES[1]} / {self.delivery}"}, FILES[1])
        if step == 1:
            return ("INCIDENT RECORD", "Restore thread", 'Cropped endorsement: “Tried it. Looks great!”',
                    f"Original: Mika asked about the handmade banner. Amani praised the banner. Case {self.delivery} names {self.original} as the original thread. Attach it to the incident.",
                    {name: name for name in RECORDS}, self.original)
        return ("FLAG VAULT" if attacking else "QUARANTINE", "Inspect flag file",
                f"Protected event folder • {self.delivery}",
                f"{self.delivery} / EVENT.FLAG\n{'Transfer the verified flag to your terminal.' if attacking else 'Move the verified flag into quarantine.'}",
                {"flag": "Retrieve flag" if attacking else "Secure flag"}, "flag")

    def view(self, user: str) -> dict:
        trail = self.trails[user]
        other = next(t for uid, t in self.trails.items() if uid != user)
        node, inspect, summary, detail, targets, _ = self.station(user)
        return {"role": "attacker" if user == self.attacker else "defender",
                "step": trail.step, "rival_step": other.step, "inspected": trail.inspected,
                "revision": trail.revision, "ends_at": self.ends_at, "node": node,
                "inspect_label": inspect, "summary": summary, "detail": detail if trail.inspected else "",
                "targets": targets if trail.inspected else {}, "feedback": trail.feedback}

    def act(self, user: str, revision: int, node: str, action: str, target: str) -> bool:
        """Called under the room lock. Stale inputs are harmless on retry/reconnect."""
        trail = self.trails[user]
        current, _, _, _, targets, correct = self.station(user)
        if revision != trail.revision or node != current:
            return False
        if action == "inspect" and not trail.inspected:
            trail.inspected = True
            trail.feedback = ""
        elif action == "route" and trail.inspected and target in targets:
            if target != correct:
                trail.feedback = ("Access denied. Compare the host or desk with the verified route."
                                  if trail.step == 0 else "Access denied. Check the source record and delivery reference.")
            else:
                trail.step += 1
                trail.inspected = False
                trail.feedback = ""
        else:
            return False
        trail.revision += 1
        return trail.step == 3
