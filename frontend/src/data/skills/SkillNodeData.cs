using Godot;

namespace LevelBlue.Data;

/// <summary>
/// Cybersecurity domain this upgrade belongs to. Inspector-visible via
/// <see cref="SkillNodeData.Domain"/>.
/// </summary>
public enum SkillDomain
{
	Network = 0,
	Cryptography = 1,
	Osint = 2,
	Hardware = 3,
}

/// <summary>
/// Immutable design-time data for one skill-tree node.
/// Runtime unlock state does not live here — that belongs to a future save layer.
/// </summary>
[GlobalClass]
public partial class SkillNodeData : Resource
{
	/// <summary>Stable id used by prerequisites, UI instantiation, and later save keys.</summary>
	[Export]
	public string SkillId { get; set; } = string.Empty;

	[Export]
	public string SkillName { get; set; } = string.Empty;

	[Export(PropertyHint.MultilineText)]
	public string Description { get; set; } = string.Empty;

	[Export]
	public SkillDomain Domain { get; set; } = SkillDomain.Network;

	[Export]
	public Texture2D Icon { get; set; }

	/// <summary>Primary currency cost to purchase one rank. Multi-resource costs are out of scope for M1.</summary>
	[Export(PropertyHint.Range, "0,999,1")]
	public int UnlockCost { get; set; }

	/// <summary>Drives the "0/1" rank counter under the diamond node.</summary>
	[Export(PropertyHint.Range, "1,9,1")]
	public int MaxRank { get; set; } = 1;

	/// <summary>
	/// Positions this node on the pan/zoom canvas, in canvas pixels at scale 1.
	/// (0, 0) is the canvas origin — typically the starter node.
	/// </summary>
	[Export]
	public Vector2 GraphPosition { get; set; } = Vector2.Zero;

	/// <summary>
	/// SkillId values that must be owned before this node can be purchased.
	/// Ids, not Resource references — see the M1 architecture note on circular .tres graphs.
	/// </summary>
	[Export]
	public string[] PrerequisiteIds { get; set; } = System.Array.Empty<string>();
}
