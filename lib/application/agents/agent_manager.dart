import '../../domain/agents/agent_profile.dart';
import '../../domain/tasks/task_role.dart';

class AgentManager {
  final Map<String, AgentProfile> _agents = <String, AgentProfile>{};

  Future<void> register(AgentProfile agent) async {
    final key = agent.id.value;
    if (_agents.containsKey(key)) {
      throw StateError('Ajan zaten kayitli: $key');
    }
    _agents[key] = agent;
  }

  Future<AgentProfile?> getById(String id) async => _agents[id];

  Future<List<AgentProfile>> activeAgents() async {
    return List<AgentProfile>.unmodifiable(
      _agents.values.where((agent) => agent.status == AgentStatus.active),
    );
  }

  Future<AgentProfile> selectForRole(TaskRole role) async {
    final active = await activeAgents();

    for (final agent in active) {
      if (_supportsRole(agent, role)) {
        return agent;
      }
    }

    throw StateError('Uygun aktif ajan bulunamadi: ${role.name}');
  }

  bool _supportsRole(AgentProfile agent, TaskRole role) {
    final roleText = role.name.toLowerCase();
    return agent.skills.any(
      (skill) => skill.toLowerCase() == roleText,
    );
  }
}
