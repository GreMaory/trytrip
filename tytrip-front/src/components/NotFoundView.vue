<template>
  <div class="page">
    <el-result icon="info" title="Page introuvable" sub-title="Cette page n’existe pas ou a été déplacée.">
      <template #extra>
        <el-button type="primary" @click="$router.push('/')">Retour à l’accueil</el-button>
      </template>
    </el-result>
  </div>
</template>
