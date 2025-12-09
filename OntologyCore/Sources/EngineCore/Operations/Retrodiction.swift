public protocol BackwardRetrodicting {
    func retrodictPrerequisites(scope: Scope?) -> [Prerequisite]
}

